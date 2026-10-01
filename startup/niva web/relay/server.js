const http = require('http');
const { WebSocketServer, WebSocket } = require('ws');

const RELAY_PORT = Number(process.env.RELAY_PORT || 8787);
const TARGET_QUERY_KEY = process.env.RELAY_TARGET_KEY || 'target';

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ ok: true, relay: 'esp32-ws-relay', targetKey: TARGET_QUERY_KEY }));
});

const wss = new WebSocketServer({ server, path: '/ws' });

const isWsUrl = (value) => /^wss?:\/\//i.test(value);

wss.on('connection', (client, req) => {
  const requestUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const target = requestUrl.searchParams.get(TARGET_QUERY_KEY) || '';

  if (!isWsUrl(target)) {
    client.close(1008, `Missing or invalid ${TARGET_QUERY_KEY} query param`);
    return;
  }

  let upstream;
  try {
    upstream = new WebSocket(target);
  } catch {
    client.close(1011, 'Failed to connect upstream');
    return;
  }

  upstream.on('open', () => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify({ relay: 'connected', target }));
    }
  });

  upstream.on('message', (message, isBinary) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message, { binary: isBinary });
    }
  });

  upstream.on('close', () => {
    if (client.readyState === WebSocket.OPEN) {
      client.close(1000, 'Upstream closed');
    }
  });

  upstream.on('error', () => {
    if (client.readyState === WebSocket.OPEN) {
      client.close(1011, 'Upstream error');
    }
  });

  client.on('message', (message, isBinary) => {
    if (upstream.readyState === WebSocket.OPEN) {
      upstream.send(message, { binary: isBinary });
    }
  });

  client.on('close', () => {
    if (upstream.readyState === WebSocket.OPEN || upstream.readyState === WebSocket.CONNECTING) {
      upstream.close();
    }
  });
});

server.listen(RELAY_PORT, () => {
  console.log(`ESP32 relay listening on http://localhost:${RELAY_PORT}`);
  console.log(`Use ws endpoint: ws://localhost:${RELAY_PORT}/ws?${TARGET_QUERY_KEY}=ws://<esp32-ip>:81/`);
});
