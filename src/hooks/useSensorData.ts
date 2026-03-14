import { useEffect, useRef, useState } from 'react';

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
};

const DEFAULT_WS_URL = 'ws://10.249.106.94:81';

export default function useSensorData(): UseSensorDataResult {
  const [data, setData] = useState<WsSensorData | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastMessageAt, setLastMessageAt] = useState<number | null>(null);

  const reconnectTimerRef = useRef<number | null>(null);

  const wsUrl = ((import.meta as ImportMeta & { env?: Record<string, string | undefined> }).env?.VITE_ESP32_WS_URL || DEFAULT_WS_URL).trim();

  useEffect(() => {
    let socket: WebSocket | null = null;
    let isUnmounted = false;

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
  }, [wsUrl]);

  return {
    data,
    isConnected,
    error,
    lastMessageAt,
    url: wsUrl,
  };
}
