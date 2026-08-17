import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

export type WsSensorData = {
  heel?: number;
  inner?: number;
  outer?: number;
  toe?: number;
  pitch?: number;
  roll?: number;
  piezo?: number;
  impact?: number;
  accZ?: number;
  [key: string]: unknown;
};

type UseSensorDataResult = {
  data: WsSensorData | null;
  isConnected: boolean;
  error: string | null;
  lastMessageAt: number | null;
  url: string;
  relayUrl: string;
  activeUrl: string;
  connectionMode: 'direct' | 'relay' | 'blocked';
  setUrl: (nextUrl: string) => void;
  setRelayUrl: (nextUrl: string) => void;
  resetUrl: () => void;
  resetRelayUrl: () => void;
  canAttemptInBrowser: boolean;
  connectionHint: string | null;
};

const DEFAULT_WS_URL = 'ws://10.249.106.94:81';
const WS_ENDPOINT_STORAGE_KEY = 'gaitguard:nexus:ws-endpoint';
const WS_ENDPOINT_QUERY_KEY = 'esp32ws';
const RELAY_ENDPOINT_STORAGE_KEY = 'gaitguard:nexus:ws-relay-endpoint';
const RELAY_ENDPOINT_QUERY_KEY = 'esp32relay';
const DEFAULT_RELAY_QUERY_KEY = 'target';

const hasWindow = () => typeof window !== 'undefined';

const isLikelyLocalHost = (hostname: string): boolean => {
  const lower = hostname.toLowerCase();
  if (lower === 'localhost' || lower === '127.0.0.1') return true;

  // RFC1918 private networks commonly used by ESP32 AP/hotspot setups.
  const privateIpv4 = /^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[0-1])\.)/;
  return privateIpv4.test(lower);
};

const toWsUrl = (rawUrl: string): string => {
  const trimmed = rawUrl.trim();
  if (!trimmed) return '';

  let candidate = trimmed;
  if (candidate.startsWith('http://')) {
    candidate = `ws://${candidate.slice('http://'.length)}`;
  } else if (candidate.startsWith('https://')) {
    candidate = `wss://${candidate.slice('https://'.length)}`;
  } else if (!/^wss?:\/\//i.test(candidate)) {
    candidate = `ws://${candidate}`;
  }

  try {
    const parsed = new URL(candidate);
    if (parsed.protocol !== 'ws:' && parsed.protocol !== 'wss:') {
      return '';
    }

    // For local ESP32 endpoints only, default to port 81 when omitted.
    if (parsed.protocol === 'ws:' && !parsed.port && isLikelyLocalHost(parsed.hostname)) {
      parsed.port = '81';
    }

    return parsed.toString();
  } catch {
    return '';
  }
};

const toRelayUrl = (rawUrl: string): string => {
  const trimmed = rawUrl.trim();
  if (!trimmed) return '';

  let candidate = trimmed;
  if (candidate.startsWith('http://')) {
    candidate = `ws://${candidate.slice('http://'.length)}`;
  } else if (candidate.startsWith('https://')) {
    candidate = `wss://${candidate.slice('https://'.length)}`;
  }

  try {
    const parsed = new URL(candidate);
    if (parsed.protocol !== 'ws:' && parsed.protocol !== 'wss:') {
      return '';
    }

    return parsed.toString();
  } catch {
    return '';
  }
};

const toRelayQueryKey = (rawKey: string): string => {
  const trimmed = rawKey.trim();
  if (!trimmed) return DEFAULT_RELAY_QUERY_KEY;
  return /^[a-zA-Z0-9_-]+$/.test(trimmed) ? trimmed : DEFAULT_RELAY_QUERY_KEY;
};

const isBlockedByMixedContent = (wsUrl: string): boolean => {
  if (!hasWindow()) return false;
  return window.location.protocol === 'https:' && wsUrl.startsWith('ws://');
};

const resolveInitialWsUrl = (): string => {
  const envUrl = (
    (import.meta as ImportMeta & { env?: Record<string, string | undefined> }).env?.VITE_ESP32_WS_URL || DEFAULT_WS_URL
  ).trim();

  if (!hasWindow()) {
    return toWsUrl(envUrl) || DEFAULT_WS_URL;
  }

  const queryUrl = toWsUrl(new URL(window.location.href).searchParams.get(WS_ENDPOINT_QUERY_KEY) || '');
  if (queryUrl) {
    window.localStorage.setItem(WS_ENDPOINT_STORAGE_KEY, queryUrl);
    return queryUrl;
  }

  const storedUrl = toWsUrl(window.localStorage.getItem(WS_ENDPOINT_STORAGE_KEY) || '');
  if (storedUrl) {
    return storedUrl;
  }

  return toWsUrl(envUrl) || DEFAULT_WS_URL;
};

const resolveInitialRelayUrl = (): string => {
  const envRelay = toRelayUrl(
    ((import.meta as ImportMeta & { env?: Record<string, string | undefined> }).env?.VITE_ESP32_WS_RELAY_URL || '').trim()
  );

  if (!hasWindow()) {
    return envRelay;
  }

  const queryRelay = toRelayUrl(new URL(window.location.href).searchParams.get(RELAY_ENDPOINT_QUERY_KEY) || '');
  if (queryRelay) {
    window.localStorage.setItem(RELAY_ENDPOINT_STORAGE_KEY, queryRelay);
    return queryRelay;
  }

  const storedRelay = toRelayUrl(window.localStorage.getItem(RELAY_ENDPOINT_STORAGE_KEY) || '');
  if (storedRelay) {
    return storedRelay;
  }

  return envRelay;
};

export default function useSensorData(): UseSensorDataResult {
  const [data, setData] = useState<WsSensorData | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastMessageAt, setLastMessageAt] = useState<number | null>(null);
  const [wsUrl, setWsUrl] = useState(resolveInitialWsUrl);
  const [relayUrl, setRelayUrlState] = useState(resolveInitialRelayUrl);

  const reconnectTimerRef = useRef<number | null>(null);
  const relayTargetQueryKey = toRelayQueryKey(
    ((import.meta as ImportMeta & { env?: Record<string, string | undefined> }).env?.VITE_ESP32_WS_RELAY_TARGET_KEY || '').trim()
  );

  const resolvedConnection = useMemo(() => {
    const blockedByMixedContent = isBlockedByMixedContent(wsUrl);

    if (!blockedByMixedContent) {
      return {
        activeUrl: wsUrl,
        mode: 'direct' as const,
        hint: null,
      };
    }

    if (relayUrl) {
      const relay = new URL(relayUrl);
      relay.searchParams.set(relayTargetQueryKey, wsUrl);

      return {
        activeUrl: relay.toString(),
        mode: 'relay' as const,
        hint: null,
      };
    }

    return {
      activeUrl: wsUrl,
      mode: 'blocked' as const,
      hint: 'This site is running on HTTPS. Browsers block ws:// endpoints here. Add a relay URL in Settings (wss://...) or open the app locally over http:// for direct ws:// links.',
    };
  }, [relayTargetQueryKey, relayUrl, wsUrl]);

  const connectionHint = resolvedConnection.mode === 'blocked' ? resolvedConnection.hint : null;

  const setUrl = useCallback((nextUrl: string) => {
    const normalized = toWsUrl(nextUrl);
    if (!normalized) {
      setError('Enter a valid WebSocket URL (example: ws://192.168.4.1:81 or wss://your-relay.example/ws).');
      return;
    }

    setError(null);
    setWsUrl(normalized);
  }, []);

  const resetUrl = useCallback(() => {
    if (hasWindow()) {
      window.localStorage.removeItem(WS_ENDPOINT_STORAGE_KEY);
    }

    const fallback = toWsUrl(
      ((import.meta as ImportMeta & { env?: Record<string, string | undefined> }).env?.VITE_ESP32_WS_URL || DEFAULT_WS_URL).trim()
    ) || DEFAULT_WS_URL;

    setError(null);
    setWsUrl(fallback);
  }, []);

  const setRelayUrl = useCallback((nextUrl: string) => {
    const normalized = toRelayUrl(nextUrl);
    if (!normalized) {
      setError('Enter a valid relay URL (example: wss://your-relay-domain/ws).');
      return;
    }

    setError(null);
    setRelayUrlState(normalized);
  }, []);

  const resetRelayUrl = useCallback(() => {
    if (hasWindow()) {
      window.localStorage.removeItem(RELAY_ENDPOINT_STORAGE_KEY);
    }

    const fallback = toRelayUrl(
      ((import.meta as ImportMeta & { env?: Record<string, string | undefined> }).env?.VITE_ESP32_WS_RELAY_URL || '').trim()
    );

    setError(null);
    setRelayUrlState(fallback);
  }, []);

  useEffect(() => {
    if (!hasWindow()) return;
    window.localStorage.setItem(WS_ENDPOINT_STORAGE_KEY, wsUrl);
  }, [wsUrl]);

  useEffect(() => {
    if (!hasWindow()) return;

    if (relayUrl) {
      window.localStorage.setItem(RELAY_ENDPOINT_STORAGE_KEY, relayUrl);
    } else {
      window.localStorage.removeItem(RELAY_ENDPOINT_STORAGE_KEY);
    }
  }, [relayUrl]);

  useEffect(() => {
    let socket: WebSocket | null = null;
    let isUnmounted = false;

    if (connectionHint) {
      setIsConnected(false);
      setError(connectionHint);
      return;
    }

    const connect = () => {
      if (isUnmounted) return;

      try {
        socket = new WebSocket(resolvedConnection.activeUrl);
      } catch {
        setError(`Invalid WebSocket URL: ${resolvedConnection.activeUrl}`);
        return;
      }

      socket.onopen = () => {
        if (isUnmounted) return;
        setIsConnected(true);
        setError(null);
      };

      socket.onmessage = (event) => {
        if (isUnmounted) return;

        try {
          const parsed = JSON.parse(String(event.data)) as WsSensorData;
          setData(parsed);
          setLastMessageAt(Date.now());
        } catch {
          setError('Received malformed JSON from ESP32 WebSocket stream.');
        }
      };

      socket.onerror = () => {
        if (isUnmounted) return;

        if (resolvedConnection.mode === 'relay') {
          setError('Relay connection error. Check VITE_ESP32_WS_RELAY_URL and verify relay can reach your ESP32 target endpoint.');
          return;
        }

        setError('WebSocket connection error. Check ESP32 IP, port, and network.');
      };

      socket.onclose = () => {
        if (isUnmounted) return;
        setIsConnected(false);

        if (reconnectTimerRef.current) {
          window.clearTimeout(reconnectTimerRef.current);
        }

        reconnectTimerRef.current = window.setTimeout(() => {
          connect();
        }, 1500);
      };
    };

    connect();

    return () => {
      isUnmounted = true;

      if (reconnectTimerRef.current) {
        window.clearTimeout(reconnectTimerRef.current);
      }

      if (socket && (socket.readyState === WebSocket.CONNECTING || socket.readyState === WebSocket.OPEN)) {
        socket.close();
      }
    };
  }, [connectionHint, resolvedConnection]);

  return {
    data,
    isConnected,
    error,
    lastMessageAt,
    url: wsUrl,
    relayUrl,
    activeUrl: resolvedConnection.activeUrl,
    connectionMode: resolvedConnection.mode,
    setUrl,
    setRelayUrl,
    resetUrl,
    resetRelayUrl,
    canAttemptInBrowser: connectionHint === null,
    connectionHint,
  };
}
