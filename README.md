# React + TypeScript + Vite

## ESP32 Live Telemetry (Web Serial)

The dashboard now supports direct USB streaming from ESP32 on the main page.

### Quick Start

1. Flash firmware that outputs CSV lines in this format:
  `H,I,O,T,Piezo,Pitch,Roll,AccZ`
2. Connect ESP32 over USB.
3. Run the app locally:
  `npm install`
  `npm run dev`
4. Open the app in Microsoft Edge or Google Chrome on localhost.
5. Go to `/main` and click the USB icon in the header.
6. Select the ESP32 COM port when prompted.

### Notes

- Expected baud rate is `115200`.
- Header/system lines such as `CALIBRATING...`, `SYSTEM_READY`, and CSV header rows are ignored automatically.
- If Web Serial is unavailable, the dashboard shows a warning banner.
- Simulation mode remains available and does not require hardware.

## ESP32 Live Telemetry (WiFi WebSocket)

The dashboard also supports direct ESP32 WebSocket JSON streaming.

### Default Endpoint

- The hook at [src/hooks/useSensorData.ts](src/hooks/useSensorData.ts) defaults to:
  `ws://10.249.106.94:81`

### Optional Override

- Create `.env.local` in project root and set:
  `VITE_ESP32_WS_URL=ws://<your-esp32-ip>:81`

### Expected JSON Payload Example

`{"heel":42,"inner":68,"outer":31,"toe":27,"pitch":-2.4,"roll":1.3,"piezo":176,"accZ":9.72}`

Mapped fields:

- `heel`, `inner`, `outer`, `toe` -> pressure widgets/heatmap
- `pitch`, `roll` -> kinematic charts
- `piezo` (or `impact`) -> impact sharpness chart

## Dataset Storage (ESP32 Stream)

- Incoming ESP32 packets from USB and WiFi are automatically persisted in browser IndexedDB.
- Store name: `gaitguard-nexus-datasets` / `esp32_samples`.
- Data fields stored per sample:
  `timestampMs, source, heel, inner, outer, toe, impact, pitch, roll, accZ`.
- In `/main`, use the `ESP32 Dataset Store` card to:
  - export all samples as CSV
  - upload CSV to backend/research storage (one-click)
  - clear stored dataset

### Backend Upload Configuration

- Add to `.env.local`:
  - `VITE_DATASET_UPLOAD_URL=https://your-api.example.com/upload`
  - `VITE_DATASET_UPLOAD_TOKEN=your_optional_bearer_token`
- Upload request format:
  - HTTP `POST` multipart form-data
  - `file` (CSV file)
  - `sampleCount`
  - `generatedAt`
  - `datasetType=esp32-biomechanics`

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Oxc](https://oxc.rs)
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/)

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the ESLint configuration

If you are developing a production application, we recommend updating the configuration to enable type-aware lint rules:

```js
export default defineConfig([
  globalIgnores(['dist']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      // Other configs...

      // Remove tseslint.configs.recommended and replace with this
      tseslint.configs.recommendedTypeChecked,
      // Alternatively, use this for stricter rules
      tseslint.configs.strictTypeChecked,
      // Optionally, add this for stylistic rules
      tseslint.configs.stylisticTypeChecked,

      // Other configs...
    ],
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.node.json', './tsconfig.app.json'],
        tsconfigRootDir: import.meta.dirname,
      },
      // other options...
    },
  },
])
```

You can also install [eslint-plugin-react-x](https://github.com/Rel1cx/eslint-react/tree/main/packages/plugins/eslint-plugin-react-x) and [eslint-plugin-react-dom](https://github.com/Rel1cx/eslint-react/tree/main/packages/plugins/eslint-plugin-react-dom) for React-specific lint rules:

```js
// eslint.config.js
import reactX from 'eslint-plugin-react-x'
import reactDom from 'eslint-plugin-react-dom'

export default defineConfig([
  globalIgnores(['dist']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      // Other configs...
      // Enable lint rules for React
      reactX.configs['recommended-typescript'],
      // Enable lint rules for React DOM
      reactDom.configs.recommended,
    ],
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.node.json', './tsconfig.app.json'],
        tsconfigRootDir: import.meta.dirname,
      },
      // other options...
    },
  },
])
```
