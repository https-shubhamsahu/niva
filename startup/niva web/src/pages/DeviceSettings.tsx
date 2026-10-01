import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import ThemeSwitch from '../components/ThemeSwitch';
import useSensorData from '../hooks/useSensorData';

type PinRow = {
  component: string;
  sensorPin: string;
  espPin: string;
  detail: string;
};

type TroubleshootingRow = {
  observation: string;
  cause: string;
  fix: string;
};

const pinMap: PinRow[] = [
  {
    component: 'MPU6050',
    sensorPin: 'VCC',
    espPin: 'VIN (5V rail)',
    detail: '5V over cable, then local regulation to 3.3V at shoe module.',
  },
  {
    component: 'MPU6050',
    sensorPin: 'GND',
    espPin: 'GND',
    detail: 'Shared return with FSR and piezo lines.',
  },
  {
    component: 'MPU6050',
    sensorPin: 'SDA',
    espPin: 'GPIO 21 + 5k pull-up to 3.3V',
    detail: 'Pocket-hub pull-up improves long-cable I2C edge quality.',
  },
  {
    component: 'MPU6050',
    sensorPin: 'SCL',
    espPin: 'GPIO 22 + 5k pull-up to 3.3V',
    detail: 'Matched pull-up with SDA for robust handshake.',
  },
  {
    component: 'MPU6050',
    sensorPin: 'AD0',
    espPin: 'GND',
    detail: 'Locks I2C address at 0x68.',
  },
  {
    component: 'FSR Heel',
    sensorPin: 'OUT',
    espPin: 'GPIO 32',
    detail: '10k pull-down to GND on 3.3V analog domain.',
  },
  {
    component: 'FSR Inner',
    sensorPin: 'OUT',
    espPin: 'GPIO 33',
    detail: 'Tracks 1st metatarsal pressure path.',
  },
  {
    component: 'FSR Outer',
    sensorPin: 'OUT',
    espPin: 'GPIO 34',
    detail: 'Tracks 5th metatarsal pressure path.',
  },
  {
    component: 'FSR Toe',
    sensorPin: 'OUT',
    espPin: 'GPIO 35',
    detail: 'Hallux push-off load monitoring.',
  },
  {
    component: 'Piezo Heel Disc',
    sensorPin: 'OUT',
    espPin: 'GPIO 36',
    detail: '1M bleed resistor and 3.3V clamp for spike-safe capture.',
  },
];

const troubleshootingRows: TroubleshootingRow[] = [
  {
    observation: 'FSR channels stay at 0',
    cause: 'Break in shoe harness continuity',
    fix: 'Continuity-check umbilical lines end-to-end and reseat connectors.',
  },
  {
    observation: 'AccZ reads 0.00',
    cause: 'SDA and SCL swapped',
    fix: 'Swap GPIO 21/22 routing or correct harness labels.',
  },
  {
    observation: 'FSR data noisy in motion',
    cause: 'EMI pickup over cable run',
    fix: 'Reduce EMA alpha toward 0.05 and verify shield ground reference.',
  },
  {
    observation: 'IMU offline at boot',
    cause: 'Voltage sag below MPU logic threshold',
    fix: 'Keep MPU VCC on VIN 5V and confirm local regulator output.',
  },
];

const architectureCards = [
  {
    title: 'Umbilical Edge Node',
    detail: 'Sense-Sleeve + Pocket-Hub linked by 1m shielded cable for deterministic signal routing.',
    icon: 'cable',
  },
  {
    title: 'Edge Compute Core',
    detail: 'ESP32 DevKit V1 with non-blocking state machines and manual I2C reset behavior.',
    icon: 'memory',
  },
  {
    title: 'Clean Power Path',
    detail: 'LiPo -> TP4056 -> LDO 3.3V. No boost converter in analog chain to reduce switching EMI.',
    icon: 'bolt',
  },
  {
    title: 'Explainable Screening',
    detail: 'Deterministic heuristics, baseline calibration, and transparent event logs for auditability.',
    icon: 'query_stats',
  },
];

const DEFAULT_HEURISTICS = {
  emaAlpha: 0.15,
  smaWindow: 10,
  stanceTarget: 60,
  baselineSteps: 20,
  ischemiaThreshold: 50,
  ischemiaMinutes: 15,
  i2cProfile: '40kHz' as const,
  staticModeRequired: true,
};

export default function DeviceSettings() {
  const [emaAlpha, setEmaAlpha] = useState(DEFAULT_HEURISTICS.emaAlpha);
  const [smaWindow, setSmaWindow] = useState(DEFAULT_HEURISTICS.smaWindow);
  const [stanceTarget, setStanceTarget] = useState(DEFAULT_HEURISTICS.stanceTarget);
  const [baselineSteps, setBaselineSteps] = useState(DEFAULT_HEURISTICS.baselineSteps);
  const [ischemiaThreshold, setIschemiaThreshold] = useState(DEFAULT_HEURISTICS.ischemiaThreshold);
  const [ischemiaMinutes, setIschemiaMinutes] = useState(DEFAULT_HEURISTICS.ischemiaMinutes);
  const [i2cProfile, setI2cProfile] = useState<'40kHz' | '100kHz'>(DEFAULT_HEURISTICS.i2cProfile);
  const [staticModeRequired, setStaticModeRequired] = useState(DEFAULT_HEURISTICS.staticModeRequired);
  const {
    data: wsData,
    isConnected: isWsConnected,
    error: wsError,
    lastMessageAt: wsLastMessageAt,
    url: wsUrl,
    relayUrl,
    activeUrl,
    connectionMode,
    setUrl: setWsUrl,
    setRelayUrl,
    resetUrl: resetWsUrl,
    resetRelayUrl,
    canAttemptInBrowser,
    connectionHint,
  } = useSensorData();
  const [wsDraftUrl, setWsDraftUrl] = useState(wsUrl);
  const [relayDraftUrl, setRelayDraftUrl] = useState(relayUrl);
  const [copyStatus, setCopyStatus] = useState('');

  useEffect(() => {
    setWsDraftUrl(wsUrl);
  }, [wsUrl]);

  useEffect(() => {
    setRelayDraftUrl(relayUrl);
  }, [relayUrl]);

  const swingTarget = 100 - stanceTarget;

  const emaSettlingSamples = useMemo(() => {
    const samples = Math.log(0.05) / Math.log(1 - emaAlpha);
    return Number.isFinite(samples) ? Math.round(samples) : 0;
  }, [emaAlpha]);

  const rawWsJson = useMemo(() => {
    if (!wsData) {
      return '{\n  "status": "Waiting for ESP32 websocket payload"\n}';
    }
    return JSON.stringify(wsData, null, 2);
  }, [wsData]);

  const wsMetrics = useMemo(() => {
    const toNumber = (value: unknown) => {
      const parsed = Number(value);
      return Number.isFinite(parsed) ? parsed : null;
    };

    return {
      heel: toNumber(wsData?.heel),
      inner: toNumber(wsData?.inner ?? wsData?.mt1),
      outer: toNumber(wsData?.outer ?? wsData?.mt5),
      toe: toNumber(wsData?.toe),
      pitch: toNumber(wsData?.pitch),
      roll: toNumber(wsData?.roll),
      piezo: toNumber(wsData?.piezo ?? wsData?.impact),
    };
  }, [wsData]);

  const handleApplyEndpoint = () => {
    setWsUrl(wsDraftUrl);
  };

  const handleResetEndpoint = () => {
    resetWsUrl();
  };

  const handleApplyRelay = () => {
    setRelayUrl(relayDraftUrl);
  };

  const handleResetRelay = () => {
    resetRelayUrl();
  };

  const handleCopyShareLink = async () => {
    if (typeof window === 'undefined') return;

    const url = new URL(window.location.href);
    url.searchParams.set('esp32ws', wsUrl);
    if (relayUrl) {
      url.searchParams.set('esp32relay', relayUrl);
    } else {
      url.searchParams.delete('esp32relay');
    }

    try {
      await navigator.clipboard.writeText(url.toString());
      setCopyStatus('Share link copied');
      window.setTimeout(() => setCopyStatus(''), 2000);
    } catch {
      setCopyStatus('Copy failed');
      window.setTimeout(() => setCopyStatus(''), 2000);
    }
  };

  const handleRestoreDefaults = () => {
    setEmaAlpha(DEFAULT_HEURISTICS.emaAlpha);
    setSmaWindow(DEFAULT_HEURISTICS.smaWindow);
    setStanceTarget(DEFAULT_HEURISTICS.stanceTarget);
    setBaselineSteps(DEFAULT_HEURISTICS.baselineSteps);
    setIschemiaThreshold(DEFAULT_HEURISTICS.ischemiaThreshold);
    setIschemiaMinutes(DEFAULT_HEURISTICS.ischemiaMinutes);
    setI2cProfile(DEFAULT_HEURISTICS.i2cProfile);
    setStaticModeRequired(DEFAULT_HEURISTICS.staticModeRequired);
  };

  return (
    <div className="w-full min-h-screen bg-[#EDEFF5] dark:bg-[#12151D] text-slate-900 dark:text-slate-100 pb-28">
      <header className="sticky top-0 z-50 border-b border-slate-200/70 dark:border-slate-800/80 bg-[#EDEFF5]/90 dark:bg-[#12151D]/90 backdrop-blur-xl">
        <div className="px-5 pt-5 pb-4">
          <div className="flex items-center justify-between">
            <Link
              to="/main"
              className="flex items-center gap-1.5 text-[11px] font-extrabold uppercase tracking-[0.18em] text-[#415AEE]"
            >
              <span className="material-symbols-outlined text-[20px]">arrow_back</span>
              Live
            </Link>

            <div className="text-center">
              <h1 className="text-[15px] font-black uppercase tracking-[0.18em]">Nexus Console</h1>
              <p className="text-[10px] font-bold uppercase tracking-[0.16em] text-slate-500">Biomechanical Risk Screening Tool</p>
            </div>

            <ThemeSwitch />
          </div>
        </div>
      </header>

      <main className="px-5 pt-5 space-y-5">
        <section className="relative overflow-hidden rounded-[30px] border border-[#415AEE]/20 bg-gradient-to-br from-[#1E2A52] via-[#213775] to-[#2D5ACF] text-white shadow-[0_20px_60px_-25px_rgba(46,93,207,0.8)]">
          <div className="absolute -right-10 -top-8 h-40 w-40 rounded-full bg-white/10 blur-2xl"></div>
          <div className="absolute -left-8 -bottom-10 h-36 w-36 rounded-full bg-cyan-300/20 blur-2xl"></div>
          <div className="relative p-5">
            <div className="flex flex-wrap items-center gap-2">
              <span className="rounded-full border border-white/30 bg-white/15 px-2.5 py-1 text-[10px] font-bold uppercase tracking-[0.14em]">
                Edge Linked
              </span>
              <span className="rounded-full border border-white/30 bg-white/10 px-2.5 py-1 text-[10px] font-bold uppercase tracking-[0.14em]">
                MQTT / Pi Broker
              </span>
              <span className="rounded-full border border-white/30 bg-white/10 px-2.5 py-1 text-[10px] font-bold uppercase tracking-[0.14em]">
                Firmware v1.0
              </span>
            </div>

            <h2 className="mt-4 text-2xl font-black tracking-tight">GaitGuard Nexus Operator Panel</h2>
            <p className="mt-2 max-w-[40ch] text-sm leading-relaxed text-white/90">
              Deterministic and explainable heuristics for neuropathy and neuro-degenerative gait risk screening.
              This page configures thresholds, transport behavior, and field diagnostics.
            </p>

            <div className="mt-5 grid grid-cols-3 gap-3 text-center">
              <div className="rounded-2xl border border-white/20 bg-white/10 p-3">
                <p className="text-[10px] font-bold uppercase tracking-[0.15em] text-white/70">I2C Profile</p>
                <p className="mt-1 text-lg font-black">{i2cProfile}</p>
              </div>
              <div className="rounded-2xl border border-white/20 bg-white/10 p-3">
                <p className="text-[10px] font-bold uppercase tracking-[0.15em] text-white/70">EMA Alpha</p>
                <p className="mt-1 text-lg font-black">{emaAlpha.toFixed(2)}</p>
              </div>
              <div className="rounded-2xl border border-white/20 bg-white/10 p-3">
                <p className="text-[10px] font-bold uppercase tracking-[0.15em] text-white/70">Baseline</p>
                <p className="mt-1 text-lg font-black">{baselineSteps} Steps</p>
              </div>
            </div>
          </div>
        </section>

        <section className="rounded-[30px] border border-slate-200/80 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-[#1A1F2B]">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h3 className="text-[13px] font-extrabold uppercase tracking-[0.14em] text-slate-800 dark:text-slate-100">ESP32 WebSocket Raw Stream</h3>
            <span className={`rounded-full px-2.5 py-1 text-[10px] font-extrabold uppercase tracking-[0.12em] ${isWsConnected ? 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400' : 'bg-slate-200 text-slate-600 dark:bg-slate-800 dark:text-slate-300'}`}>
              {isWsConnected ? 'Connected' : 'Disconnected'}
            </span>
          </div>

          <div className="mt-3 rounded-2xl border border-slate-200 bg-slate-50 p-3 dark:border-slate-700 dark:bg-slate-900">
            <p className="text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Connection Endpoint</p>
            <div className="mt-2 flex flex-col gap-2 sm:flex-row">
              <input
                value={wsDraftUrl}
                onChange={(event) => setWsDraftUrl(event.target.value)}
                placeholder="ws://192.168.4.1:81"
                className="w-full rounded-xl border border-slate-200 bg-white px-3 py-2 font-mono text-[12px] text-slate-700 outline-none focus:border-[#415AEE] dark:border-slate-700 dark:bg-slate-950 dark:text-slate-200"
              />
              <button
                onClick={handleApplyEndpoint}
                className="rounded-xl bg-[#415AEE] px-3 py-2 text-[11px] font-extrabold uppercase tracking-[0.12em] text-white"
              >
                Apply
              </button>
              <button
                onClick={handleResetEndpoint}
                className="rounded-xl bg-slate-200 px-3 py-2 text-[11px] font-extrabold uppercase tracking-[0.12em] text-slate-700 dark:bg-slate-800 dark:text-slate-200"
              >
                Reset
              </button>
            </div>

            <p className="mt-3 text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Relay Endpoint (WSS)</p>
            <div className="mt-2 flex flex-col gap-2 sm:flex-row">
              <input
                value={relayDraftUrl}
                onChange={(event) => setRelayDraftUrl(event.target.value)}
                placeholder="wss://your-relay-domain/ws"
                className="w-full rounded-xl border border-slate-200 bg-white px-3 py-2 font-mono text-[12px] text-slate-700 outline-none focus:border-[#415AEE] dark:border-slate-700 dark:bg-slate-950 dark:text-slate-200"
              />
              <button
                onClick={handleApplyRelay}
                className="rounded-xl bg-[#415AEE] px-3 py-2 text-[11px] font-extrabold uppercase tracking-[0.12em] text-white"
              >
                Apply
              </button>
              <button
                onClick={handleResetRelay}
                className="rounded-xl bg-slate-200 px-3 py-2 text-[11px] font-extrabold uppercase tracking-[0.12em] text-slate-700 dark:bg-slate-800 dark:text-slate-200"
              >
                Reset
              </button>
            </div>

            <div className="mt-2 flex flex-wrap gap-2">
              <button
                onClick={() => setWsDraftUrl('ws://192.168.4.1:81')}
                className="rounded-full border border-slate-300 px-2.5 py-1 text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-600 dark:border-slate-600 dark:text-slate-300"
              >
                ESP32 AP Preset
              </button>
              <button
                onClick={handleCopyShareLink}
                className="rounded-full border border-[#415AEE]/40 px-2.5 py-1 text-[10px] font-extrabold uppercase tracking-[0.12em] text-[#415AEE]"
              >
                Copy Share Link
              </button>
              {copyStatus && (
                <span className="rounded-full bg-emerald-500/10 px-2.5 py-1 text-[10px] font-extrabold uppercase tracking-[0.12em] text-emerald-600 dark:text-emerald-400">
                  {copyStatus}
                </span>
              )}
            </div>

            <p className="mt-2 text-[11px] text-slate-500 dark:text-slate-400">
              Hotspot mode: connect phone/laptop and ESP32 to the same hotspot, set the ESP32 IP endpoint, and press Apply.
            </p>
            {!canAttemptInBrowser && connectionHint && (
              <p className="mt-2 text-[11px] font-semibold text-amber-600 dark:text-amber-400">{connectionHint}</p>
            )}
          </div>

          <div className="mt-3 rounded-2xl border border-slate-200 bg-slate-50 p-3 dark:border-slate-700 dark:bg-slate-900">
            <p className="text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Endpoint</p>
            <p className="mt-1 break-all font-mono text-[12px] text-slate-700 dark:text-slate-200">{wsUrl}</p>
            <p className="mt-2 text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Relay</p>
            <p className="mt-1 break-all font-mono text-[12px] text-slate-700 dark:text-slate-200">{relayUrl || 'not configured'}</p>
            <p className="mt-2 text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Active Route</p>
            <p className="mt-1 break-all font-mono text-[12px] text-slate-700 dark:text-slate-200">{activeUrl}</p>
            <p className="mt-2 text-[11px] text-slate-500 dark:text-slate-400">Mode: <span className="font-semibold uppercase">{connectionMode}</span></p>
            <p className="mt-2 text-[11px] text-slate-500 dark:text-slate-400">
              Last packet: {wsLastMessageAt ? new Date(wsLastMessageAt).toLocaleTimeString() : 'No packet yet'}
            </p>
            {wsError && (
              <p className="mt-2 text-[11px] font-semibold text-amber-600 dark:text-amber-400">{wsError}</p>
            )}
          </div>

          <div className="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
            <div className="rounded-2xl border border-slate-200 p-3 dark:border-slate-700">
              <p className="text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Heel</p>
              <p className="mt-1 text-lg font-black text-slate-800 dark:text-slate-100">{wsMetrics.heel ?? '--'}</p>
            </div>
            <div className="rounded-2xl border border-slate-200 p-3 dark:border-slate-700">
              <p className="text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Inner</p>
              <p className="mt-1 text-lg font-black text-slate-800 dark:text-slate-100">{wsMetrics.inner ?? '--'}</p>
            </div>
            <div className="rounded-2xl border border-slate-200 p-3 dark:border-slate-700">
              <p className="text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Outer</p>
              <p className="mt-1 text-lg font-black text-slate-800 dark:text-slate-100">{wsMetrics.outer ?? '--'}</p>
            </div>
            <div className="rounded-2xl border border-slate-200 p-3 dark:border-slate-700">
              <p className="text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Toe</p>
              <p className="mt-1 text-lg font-black text-slate-800 dark:text-slate-100">{wsMetrics.toe ?? '--'}</p>
            </div>
            <div className="rounded-2xl border border-slate-200 p-3 dark:border-slate-700">
              <p className="text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Pitch</p>
              <p className="mt-1 text-lg font-black text-slate-800 dark:text-slate-100">{wsMetrics.pitch ?? '--'}</p>
            </div>
            <div className="rounded-2xl border border-slate-200 p-3 dark:border-slate-700">
              <p className="text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Roll</p>
              <p className="mt-1 text-lg font-black text-slate-800 dark:text-slate-100">{wsMetrics.roll ?? '--'}</p>
            </div>
            <div className="rounded-2xl border border-slate-200 p-3 dark:border-slate-700">
              <p className="text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Piezo</p>
              <p className="mt-1 text-lg font-black text-slate-800 dark:text-slate-100">{wsMetrics.piezo ?? '--'}</p>
            </div>
          </div>

          <div className="mt-3">
            <p className="text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Raw JSON</p>
            <pre className="mt-2 max-h-64 overflow-auto rounded-2xl border border-slate-200 bg-slate-950 p-3 text-[11px] leading-relaxed text-emerald-300 dark:border-slate-700">{rawWsJson}</pre>
          </div>
        </section>

        <section className="grid grid-cols-1 gap-3">
          {architectureCards.map((card) => (
            <article
              key={card.title}
              className="rounded-[26px] border border-slate-200/80 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-[#1A1F2B]"
            >
              <div className="flex items-start gap-3">
                <div className="mt-0.5 flex size-10 shrink-0 items-center justify-center rounded-xl bg-[#415AEE]/10 text-[#415AEE]">
                  <span className="material-symbols-outlined">{card.icon}</span>
                </div>
                <div>
                  <h3 className="text-[13px] font-extrabold uppercase tracking-[0.12em] text-slate-800 dark:text-slate-100">{card.title}</h3>
                  <p className="mt-1.5 text-sm leading-relaxed text-slate-600 dark:text-slate-300">{card.detail}</p>
                </div>
              </div>
            </article>
          ))}
        </section>

        <section className="rounded-[30px] border border-slate-200/80 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-[#1A1F2B]">
          <div className="flex items-center justify-between">
            <h3 className="text-[13px] font-extrabold uppercase tracking-[0.14em] text-slate-800 dark:text-slate-100">Heuristic Controls</h3>
            <button
              onClick={handleRestoreDefaults}
              className="rounded-full bg-[#415AEE] px-3 py-1.5 text-[10px] font-extrabold uppercase tracking-[0.14em] text-white"
            >
              Default Settings
            </button>
          </div>

          <div className="mt-4 space-y-4">
            <label className="block">
              <div className="flex items-baseline justify-between text-[12px] font-bold uppercase tracking-[0.12em] text-slate-500">
                <span>EMA Alpha</span>
                <span className="text-[#415AEE]">{emaAlpha.toFixed(2)}</span>
              </div>
              <input
                type="range"
                min={0.05}
                max={0.4}
                step={0.01}
                value={emaAlpha}
                onChange={(event) => setEmaAlpha(Number(event.target.value))}
                className="mt-2 w-full accent-[#415AEE]"
              />
              <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">Approximate filter settling: {emaSettlingSamples} samples to 95% response.</p>
            </label>

            <label className="block">
              <div className="flex items-baseline justify-between text-[12px] font-bold uppercase tracking-[0.12em] text-slate-500">
                <span>SMA Persistence Window</span>
                <span className="text-[#415AEE]">{smaWindow} steps</span>
              </div>
              <input
                type="range"
                min={5}
                max={20}
                step={1}
                value={smaWindow}
                onChange={(event) => setSmaWindow(Number(event.target.value))}
                className="mt-2 w-full accent-[#415AEE]"
              />
            </label>

            <div className="grid grid-cols-2 gap-3">
              <label className="rounded-2xl border border-slate-200 p-3 dark:border-slate-700">
                <p className="text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Stance Target</p>
                <input
                  type="number"
                  min={50}
                  max={70}
                  value={stanceTarget}
                  onChange={(event) => setStanceTarget(Number(event.target.value))}
                  className="mt-2 w-full rounded-lg border border-slate-200 bg-slate-50 px-2 py-1.5 text-sm font-semibold text-slate-700 outline-none focus:border-[#415AEE] dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100"
                />
                <p className="mt-1 text-[11px] text-slate-500 dark:text-slate-400">Swing target auto-updates to {swingTarget}%.</p>
              </label>

              <label className="rounded-2xl border border-slate-200 p-3 dark:border-slate-700">
                <p className="text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Calibration Steps</p>
                <input
                  type="number"
                  min={10}
                  max={50}
                  value={baselineSteps}
                  onChange={(event) => setBaselineSteps(Number(event.target.value))}
                  className="mt-2 w-full rounded-lg border border-slate-200 bg-slate-50 px-2 py-1.5 text-sm font-semibold text-slate-700 outline-none focus:border-[#415AEE] dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100"
                />
                <p className="mt-1 text-[11px] text-slate-500 dark:text-slate-400">Personalized baseline around mu and sigma only.</p>
              </label>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <label className="rounded-2xl border border-slate-200 p-3 dark:border-slate-700">
                <p className="text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Ischemic Pressure Threshold</p>
                <input
                  type="number"
                  min={40}
                  max={80}
                  value={ischemiaThreshold}
                  onChange={(event) => setIschemiaThreshold(Number(event.target.value))}
                  className="mt-2 w-full rounded-lg border border-slate-200 bg-slate-50 px-2 py-1.5 text-sm font-semibold text-slate-700 outline-none focus:border-[#415AEE] dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100"
                />
                <p className="mt-1 text-[11px] text-slate-500 dark:text-slate-400">Equivalent capillary occlusion guard rail (mmHg).</p>
              </label>

              <label className="rounded-2xl border border-slate-200 p-3 dark:border-slate-700">
                <p className="text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-500">Static Exposure Window</p>
                <input
                  type="number"
                  min={5}
                  max={30}
                  value={ischemiaMinutes}
                  onChange={(event) => setIschemiaMinutes(Number(event.target.value))}
                  className="mt-2 w-full rounded-lg border border-slate-200 bg-slate-50 px-2 py-1.5 text-sm font-semibold text-slate-700 outline-none focus:border-[#415AEE] dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100"
                />
                <p className="mt-1 text-[11px] text-slate-500 dark:text-slate-400">Alert when sustained above threshold for this duration.</p>
              </label>
            </div>

            <div className="rounded-2xl border border-dashed border-slate-300 p-3 dark:border-slate-700">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div>
                  <p className="text-[11px] font-extrabold uppercase tracking-[0.12em] text-slate-600 dark:text-slate-300">I2C Bus Profile</p>
                  <p className="text-xs text-slate-500 dark:text-slate-400">40kHz is preferred for 1m cable integrity.</p>
                </div>
                <div className="flex rounded-full bg-slate-100 p-1 dark:bg-slate-900">
                  <button
                    onClick={() => setI2cProfile('40kHz')}
                    className={`rounded-full px-3 py-1 text-xs font-bold ${i2cProfile === '40kHz' ? 'bg-[#415AEE] text-white' : 'text-slate-500'}`}
                  >
                    40kHz
                  </button>
                  <button
                    onClick={() => setI2cProfile('100kHz')}
                    className={`rounded-full px-3 py-1 text-xs font-bold ${i2cProfile === '100kHz' ? 'bg-[#415AEE] text-white' : 'text-slate-500'}`}
                  >
                    100kHz
                  </button>
                </div>
              </div>

              <div className="mt-3 flex items-center justify-between rounded-xl bg-slate-50 px-3 py-2.5 dark:bg-slate-900">
                <div>
                  <p className="text-xs font-semibold text-slate-700 dark:text-slate-200">Require static IMU mode for ischemic alerts</p>
                  <p className="text-[11px] text-slate-500 dark:text-slate-400">Prevents false positives during short transient loads.</p>
                </div>
                <button
                  onClick={() => setStaticModeRequired((prev) => !prev)}
                  className={`h-7 w-12 rounded-full p-1 transition-colors ${staticModeRequired ? 'bg-emerald-500' : 'bg-slate-300 dark:bg-slate-700'}`}
                  aria-label="Toggle static mode requirement"
                >
                  <span
                    className={`block h-5 w-5 rounded-full bg-white transition-transform ${staticModeRequired ? 'translate-x-5' : 'translate-x-0'}`}
                  ></span>
                </button>
              </div>
            </div>
          </div>
        </section>

        <section className="rounded-[30px] border border-slate-200/80 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-[#1A1F2B]">
          <h3 className="text-[13px] font-extrabold uppercase tracking-[0.14em] text-slate-800 dark:text-slate-100">Pin-to-Pin Connection Matrix</h3>
          <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">Reference map for field wiring, bench validation, and rapid replacement.</p>

          <div className="mt-4 overflow-hidden rounded-2xl border border-slate-200 dark:border-slate-700">
            <div className="grid grid-cols-4 bg-slate-100 px-3 py-2 text-[10px] font-extrabold uppercase tracking-[0.12em] text-slate-600 dark:bg-slate-900 dark:text-slate-300">
              <p>Component</p>
              <p>Sensor Pin</p>
              <p>ESP32 Rail</p>
              <p>Connection Detail</p>
            </div>
            <div className="divide-y divide-slate-200 dark:divide-slate-700">
              {pinMap.map((row) => (
                <div key={`${row.component}-${row.sensorPin}`} className="grid grid-cols-4 gap-2 px-3 py-2.5 text-[11px] text-slate-700 dark:text-slate-200">
                  <p className="font-semibold">{row.component}</p>
                  <p>{row.sensorPin}</p>
                  <p>{row.espPin}</p>
                  <p className="text-slate-500 dark:text-slate-400">{row.detail}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="rounded-[30px] border border-slate-200/80 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-[#1A1F2B]">
          <h3 className="text-[13px] font-extrabold uppercase tracking-[0.14em] text-slate-800 dark:text-slate-100">Hardware Why Log</h3>
          <div className="mt-4 space-y-3">
            <article className="rounded-2xl bg-[#415AEE]/8 p-3.5 dark:bg-[#415AEE]/10">
              <p className="text-[11px] font-extrabold uppercase tracking-[0.12em] text-[#415AEE]">Power Distribution</p>
              <p className="mt-1 text-sm text-slate-700 dark:text-slate-200">MPU VCC moved from 3.3V to VIN 5V because 1m cable loss reduced logic rail below stable operation.</p>
            </article>
            <article className="rounded-2xl bg-emerald-500/8 p-3.5 dark:bg-emerald-500/10">
              <p className="text-[11px] font-extrabold uppercase tracking-[0.12em] text-emerald-600 dark:text-emerald-400">I2C Stability</p>
              <p className="mt-1 text-sm text-slate-700 dark:text-slate-200">Dual 10k in parallel (5k effective) pull-ups at pocket-hub side sharpen SDA/SCL transitions on long cable.</p>
            </article>
            <article className="rounded-2xl bg-amber-500/10 p-3.5">
              <p className="text-[11px] font-extrabold uppercase tracking-[0.12em] text-amber-600">Orientation Discipline</p>
              <p className="mt-1 text-sm text-slate-700 dark:text-slate-200">MPU X axis to toe (pitch), Y axis lateral (roll), pins toward medial arch for consistent kinematic interpretation.</p>
            </article>
          </div>
        </section>

        <section className="rounded-[30px] border border-slate-200/80 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-[#1A1F2B]">
          <h3 className="text-[13px] font-extrabold uppercase tracking-[0.14em] text-slate-800 dark:text-slate-100">Data Troubleshooting Matrix</h3>
          <div className="mt-4 space-y-3">
            {troubleshootingRows.map((row) => (
              <article key={row.observation} className="rounded-2xl border border-slate-200 p-3 dark:border-slate-700">
                <p className="text-[11px] font-extrabold uppercase tracking-[0.12em] text-[#1A1D24] dark:text-slate-100">{row.observation}</p>
                <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">Likely cause: {row.cause}</p>
                <p className="mt-1 text-sm text-slate-700 dark:text-slate-200">Fix: {row.fix}</p>
              </article>
            ))}
          </div>
        </section>
      </main>
    </div>
  );
}
