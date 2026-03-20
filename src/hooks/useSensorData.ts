import { useCallback, useEffect, useRef, useState } from 'react';

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
  setUrl: (nextUrl: string) => void;
  resetUrl: () => void;
  canAttemptInBrowser: boolean;
  connectionHint: string | null;
};

const DEFAULT_WS_URL = 'ws://10.249.106.94:81';
const WS_ENDPOINT_STORAGE_KEY = 'gaitguard:nexus:ws-endpoint';
const WS_ENDPOINT_QUERY_KEY = 'esp32ws';

const hasWindow = () => typeof window !== 'undefined';

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
    if (!parsed.port) {
      parsed.port = '81';
    }
    return parsed.toString();
  } catch {
    return '';
  }
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

export default function useSensorData(): UseSensorDataResult {
  const [data, setData] = useState<WsSensorData | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastMessageAt, setLastMessageAt] = useState<number | null>(null);
  const [wsUrl, setWsUrl] = useState(resolveInitialWsUrl);

  const reconnectTimerRef = useRef<number | null>(null);

  const connectionHint = isBlockedByMixedContent(wsUrl)
    ? 'This site is running on HTTPS. Browsers block ws:// endpoints here. Use a wss:// relay endpoint or open the app locally over http:// for direct ESP32 ws:// links.'
    : null;

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

  useEffect(() => {
    if (!hasWindow()) return;
    window.localStorage.setItem(WS_ENDPOINT_STORAGE_KEY, wsUrl);
  }, [wsUrl]);

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
        socket = new WebSocket(wsUrl);
      } catch {
        setError(`Invalid WebSocket URL: ${wsUrl}`);
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
  }, [connectionHint, wsUrl]);

  return {
    data,
    isConnected,
    error,
    lastMessageAt,
    url: wsUrl,
    setUrl,
    resetUrl,
    canAttemptInBrowser: connectionHint === null,
    connectionHint,
  };
}
