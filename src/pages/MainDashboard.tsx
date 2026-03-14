import { useCallback, useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { AreaChart, Area, LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, RadialBarChart, RadialBar, PolarGrid, PolarRadiusAxis, Label } from 'recharts';
import FootHeatmap from '../components/FootHeatmap';
import { generateGaitFrame } from '../utils/simulationEngine';
import type { GaitMode } from '../utils/simulationEngine';
import { parseEsp32CsvLine } from '../utils/esp32Telemetry';
import { BiomechanicsEngine } from '../utils/biomechanicsEngine';
import type { CopPoint, GaitPhase, RawSensorPacket, StabilityBand } from '../utils/biomechanicsEngine';
import { clearTelemetryDataset, exportTelemetryCsv, getTelemetrySampleCount, insertTelemetrySamples } from '../utils/telemetryDatasetStore';
import type { DiseaseLabel, TelemetrySample, TelemetrySource } from '../utils/telemetryDatasetStore';
import { getDatasetUploadEndpoint, uploadDatasetCsvToBackend } from '../utils/researchUpload';
import DiseaseSelector from '../components/DiseaseSelector';
import ThemeSwitch from '../components/ThemeSwitch';
import useSensorData from '../hooks/useSensorData';

const DATASET_DISEASE_OPTIONS: DiseaseLabel[] = [
  'Unknown',
  'Normal',
  'Parkinson',
  'Stroke',
  'Neuropathy',
  'Foot Drop',
  'Ataxia',
];

type WebSerialPort = {
  open: (options: { baudRate: number }) => Promise<void>;
  close: () => Promise<void>;
  readable: ReadableStream<BufferSource> | null;
};

export default function MainDashboard() {
  const [score, setScore] = useState(92);
  const [isAlertVisible, setIsAlertVisible] = useState(false);
  const [isConnected, setIsConnected] = useState(false);
  const [isSerialSupported, setIsSerialSupported] = useState(false);
  const [serialStatus, setSerialStatus] = useState('Disconnected');
  const [serialError, setSerialError] = useState<string | null>(null);
  const [lastPacketAt, setLastPacketAt] = useState<number | null>(null);
  const [gaitPhase, setGaitPhase] = useState<GaitPhase>('SWING');
  const [cadenceSpm, setCadenceSpm] = useState(0);
  const [stepCount, setStepCount] = useState(0);
  const [stabilityBand, setStabilityBand] = useState<StabilityBand>('stable');
  const [impactLevel, setImpactLevel] = useState(0);
  const [copPoint, setCopPoint] = useState<CopPoint>({ x: 0.5, y: 0 });
  const [copTrail, setCopTrail] = useState<CopPoint[]>([{ x: 0.5, y: 0 }]);
  const [anomalyFlags, setAnomalyFlags] = useState<string[]>([]);
  const [datasetCount, setDatasetCount] = useState(0);
  const [datasetStatus, setDatasetStatus] = useState('Dataset idle');
  const [datasetError, setDatasetError] = useState<string | null>(null);
  const [datasetSavedAt, setDatasetSavedAt] = useState<number | null>(null);
  const [datasetSessionId, setDatasetSessionId] = useState(`session-${new Date().toISOString().slice(0, 10)}`);
  const [datasetTrialId, setDatasetTrialId] = useState('trial-001');
  const [datasetDiseaseLabel, setDatasetDiseaseLabel] = useState<DiseaseLabel>('Unknown');
  const [isUploadingDataset, setIsUploadingDataset] = useState(false);
  const [uploadStatus, setUploadStatus] = useState('Upload idle');
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [uploadSuccessAt, setUploadSuccessAt] = useState<number | null>(null);
  const {
    data: wsData,
    isConnected: isWsConnected,
    error: wsError,
    lastMessageAt: wsLastMessageAt,
    url: wsUrl,
  } = useSensorData();
  
  // Simulation Engine State
  const [isSimulating, setIsSimulating] = useState(false);
  const [simMode, setSimMode] = useState<GaitMode>('Normal');
  const [isDemoMode, setIsDemoMode] = useState(false);
  const [simExplanation, setSimExplanation] = useState("Balanced pressure progression and stable temporal parameters detected.");
  const [stanceRatioStr, setStanceRatioStr] = useState("62:38");
  
  // Real-time telemetry states
  const [fsrData, setFsrData] = useState([
    { sensor: 'Heel', val: 45 },
    { sensor: '1st Met', val: 70 },
    { sensor: '5th Met', val: 25 },
    { sensor: 'Hallux', val: 20 },
  ]);
  const [mlpi, setMlpi] = useState(45);
  const [swayData, setSwayData] = useState([...Array(15)].map((_, i) => ({ time: i, roll: (Math.random() - 0.5) * 5, pitch: (Math.random() - 0.5) * 2 })));
  const [impactData, setImpactData] = useState([...Array(15)].map((_, i) => ({ time: i, impact: Math.random() < 0.2 ? 400 + Math.random()*200 : 20 + Math.random()*10 })));
  const [integral, setIntegral] = useState(42);

  const serialPortRef = useRef<WebSerialPort | null>(null);
  const serialReaderRef = useRef<ReadableStreamDefaultReader<string> | null>(null);
  const biomechanicsRef = useRef(new BiomechanicsEngine());
  const datasetQueueRef = useRef<TelemetrySample[]>([]);
  const datasetSessionIdRef = useRef(datasetSessionId);
  const datasetTrialIdRef = useRef(datasetTrialId);
  const datasetDiseaseLabelRef = useRef<DiseaseLabel>(datasetDiseaseLabel);
  const isFlushingDatasetRef = useRef(false);
  const isConnectingRef = useRef(false);
  const tickRef = useRef(15);
  const isSimulatingRef = useRef(isSimulating);
  const simModeRef = useRef(simMode);
  const uploadEndpoint = getDatasetUploadEndpoint();

  const getSerialApi = () => {
    return (navigator as Navigator & { serial?: { requestPort: () => Promise<WebSerialPort> } }).serial;
  };

  const enqueueDatasetSample = useCallback((
    packet: RawSensorPacket,
    source: TelemetrySource,
    mode: 'live' | 'simulation',
    diseaseLabelOverride?: DiseaseLabel,
  ) => {
    datasetQueueRef.current.push({
      timestampMs: packet.timestampMs,
      source,
      sessionId: datasetSessionIdRef.current.trim() || 'session-unassigned',
      trialId: datasetTrialIdRef.current.trim() || 'trial-001',
      diseaseLabel: diseaseLabelOverride || datasetDiseaseLabelRef.current,
      mode,
      heel: packet.heel,
      inner: packet.inner,
      outer: packet.outer,
      toe: packet.toe,
      impact: packet.impact,
      pitch: packet.pitch,
      roll: packet.roll,
      accZ: packet.accZ,
    });
  }, []);

  const flushDatasetQueue = useCallback(async () => {
    if (isFlushingDatasetRef.current) return;
    if (datasetQueueRef.current.length === 0) return;

    isFlushingDatasetRef.current = true;

    const batch = [...datasetQueueRef.current];
    datasetQueueRef.current = [];

    try {
      await insertTelemetrySamples(batch);
      setDatasetCount((prev) => prev + batch.length);
      setDatasetSavedAt(Date.now());
      setDatasetStatus(`Saved ${batch.length} sample${batch.length > 1 ? 's' : ''}`);
      setDatasetError(null);
    } catch (error) {
      datasetQueueRef.current = [...batch, ...datasetQueueRef.current];
      const message = error instanceof Error ? error.message : 'Failed to write dataset batch.';
      setDatasetError(message);
      setDatasetStatus('Dataset write error');
    } finally {
      isFlushingDatasetRef.current = false;
    }
  }, []);

  const handleExportDataset = useCallback(async () => {
    try {
      setDatasetStatus('Preparing CSV export...');
      const csv = await exportTelemetryCsv();
      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
      const objectUrl = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = objectUrl;
      link.download = `gaitguard_esp32_dataset_${new Date().toISOString().replace(/[:.]/g, '-')}.csv`;
      link.click();
      URL.revokeObjectURL(objectUrl);
      setDatasetStatus('Dataset CSV exported');
      setDatasetError(null);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Failed to export dataset.';
      setDatasetError(message);
      setDatasetStatus('Dataset export failed');
    }
  }, []);

  const handleClearDataset = useCallback(async () => {
    try {
      await clearTelemetryDataset();
      datasetQueueRef.current = [];
      setDatasetCount(0);
      setDatasetSavedAt(null);
      setDatasetStatus('Dataset cleared');
      setDatasetError(null);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Failed to clear dataset.';
      setDatasetError(message);
      setDatasetStatus('Dataset clear failed');
    }
  }, []);

  const handleUploadDataset = useCallback(async () => {
    if (isUploadingDataset) return;

    if (!uploadEndpoint) {
      setUploadError('Set VITE_DATASET_UPLOAD_URL in .env.local to enable one-click backend upload.');
      setUploadStatus('Upload endpoint missing');
      return;
    }

    try {
      setIsUploadingDataset(true);
      setUploadStatus('Flushing latest samples...');
      setUploadError(null);

      await flushDatasetQueue();

      const sampleCount = await getTelemetrySampleCount();
      if (sampleCount === 0) {
        setUploadStatus('No samples available to upload');
        return;
      }

      setUploadStatus('Preparing CSV for backend upload...');
      const csv = await exportTelemetryCsv();

      setUploadStatus('Uploading to research storage...');
      const result = await uploadDatasetCsvToBackend({
        csvContent: csv,
        sampleCount,
        metadata: {
          sessionId: datasetSessionId.trim() || 'session-unassigned',
          trialId: datasetTrialId.trim() || 'trial-001',
          diseaseLabel: datasetDiseaseLabel,
        },
      });

      setUploadStatus(`Upload complete (${sampleCount} samples, HTTP ${result.statusCode})`);
      setUploadSuccessAt(Date.now());
      setUploadError(null);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Dataset upload failed.';
      setUploadError(message);
      setUploadStatus('Upload failed');
    } finally {
      setIsUploadingDataset(false);
    }
  }, [datasetDiseaseLabel, datasetSessionId, datasetTrialId, flushDatasetQueue, isUploadingDataset, uploadEndpoint]);

  const applyBiomechanicsPacket = useCallback((packet: RawSensorPacket) => {
    const metrics = biomechanicsRef.current.process(packet);
    const tick = tickRef.current++;

    setFsrData([
      { sensor: 'Heel', val: metrics.filteredPressure.heel },
      { sensor: '1st Met', val: metrics.filteredPressure.inner },
      { sensor: '5th Met', val: metrics.filteredPressure.outer },
      { sensor: 'Hallux', val: metrics.filteredPressure.toe },
    ]);

    setMlpi(Number(metrics.mlpi.toFixed(1)));

    setSwayData((prev) => [
      ...prev.slice(1),
      { time: tick, roll: packet.roll, pitch: packet.pitch },
    ]);

    setImpactData((prev) => [
      ...prev.slice(1),
      { time: tick, impact: packet.impact },
    ]);

    setScore(metrics.stabilityScore);
    setStanceRatioStr(`${metrics.stancePct}:${metrics.swingPct}`);
    setIntegral(metrics.ischemicIntegralPct);
    setGaitPhase(metrics.gaitPhase);
    setCadenceSpm(metrics.cadenceSpm);
    setStepCount(metrics.stepCount);
    setStabilityBand(metrics.stabilityBand);
    setImpactLevel(metrics.impactLevel);
    setCopPoint(metrics.cop);
    setCopTrail((prev) => [...prev.slice(-24), metrics.cop]);
    setAnomalyFlags(metrics.anomalyFlags);
    setLastPacketAt(metrics.timestampMs);

    if (metrics.ischemicIntegralPct > 50) {
      setIsAlertVisible(true);
    }
  }, []);

  const applyWsFrame = useCallback((payload: Record<string, unknown>) => {
    if (isSimulatingRef.current || isConnected) return;

    const toNumber = (value: unknown) => {
      const parsed = Number(value);
      return Number.isFinite(parsed) ? parsed : 0;
    };

    const packet: RawSensorPacket = {
      heel: toNumber(payload.heel ?? 0),
      inner: toNumber(payload.inner ?? payload.mt1 ?? 0),
      outer: toNumber(payload.outer ?? payload.mt5 ?? 0),
      toe: toNumber(payload.toe ?? 0),
      impact: toNumber(payload.piezo ?? payload.impact ?? 0),
      pitch: toNumber(payload.pitch ?? 0),
      roll: toNumber(payload.roll ?? 0),
      accZ: toNumber(payload.accZ ?? 0),
      timestampMs: Date.now(),
    };

    enqueueDatasetSample(packet, 'ws', 'live');
    applyBiomechanicsPacket(packet);
  }, [applyBiomechanicsPacket, enqueueDatasetSample, isConnected]);

  const applySerialFrame = useCallback((line: string) => {
    if (isSimulatingRef.current) return;

    const frame = parseEsp32CsvLine(line);
    if (!frame) return;

    const packet: RawSensorPacket = {
      heel: frame.heelRaw,
      inner: frame.mt1Raw,
      outer: frame.mt5Raw,
      toe: frame.toeRaw,
      impact: frame.piezoPeak,
      pitch: frame.pitchDeg,
      roll: frame.rollDeg,
      accZ: frame.accZ,
      timestampMs: frame.timestampMs,
    };

    enqueueDatasetSample(packet, 'usb', 'live');
    applyBiomechanicsPacket(packet);
  }, [applyBiomechanicsPacket, enqueueDatasetSample]);

  const disconnectSerial = useCallback(async () => {
    try {
      await serialReaderRef.current?.cancel();
    } catch {
      // Ignore cancellation errors from already closed streams.
    }

    try {
      serialReaderRef.current?.releaseLock();
    } catch {
      // Reader lock may already be released.
    }
    serialReaderRef.current = null;

    try {
      await serialPortRef.current?.close();
    } catch {
      // Ignore close errors from disconnected USB sessions.
    }
    serialPortRef.current = null;

    setIsConnected(false);
    setSerialStatus('Disconnected');
  }, []);

  const connectSerial = useCallback(async () => {
    if (isConnectingRef.current || isConnected) return;

    const serialApi = getSerialApi();
    if (!serialApi) {
      setSerialError('Web Serial is unavailable. Use Chromium-based browser over localhost/https.');
      return;
    }

    isConnectingRef.current = true;
    setSerialError(null);
    setSerialStatus('Connecting...');

    try {
      const port = await serialApi.requestPort();
      await port.open({ baudRate: 115200 });

      serialPortRef.current = port;
      setIsConnected(true);
      setSerialStatus('USB Serial Connected');

      const decoder = new TextDecoderStream();
      const readable = port.readable;
      if (!readable) throw new Error('Serial stream is unavailable on selected port.');

      const pipePromise = readable.pipeTo(decoder.writable);
      const reader = decoder.readable.getReader();
      serialReaderRef.current = reader;

      let buffer = '';
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        if (!value) continue;

        buffer += value;
        const lines = buffer.split(/\r?\n/);
        buffer = lines.pop() ?? '';

        for (const line of lines) {
          applySerialFrame(line);
        }
      }

      try {
        await pipePromise;
      } catch {
        // Ignore abort errors raised when user disconnects.
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unable to start serial stream.';
      setSerialError(message);
      setSerialStatus('Connection Error');
    } finally {
      isConnectingRef.current = false;
      if (serialPortRef.current) {
        await disconnectSerial();
      }
    }
  }, [applySerialFrame, disconnectSerial, isConnected]);

  useEffect(() => {
    const serialApi = getSerialApi();
    setIsSerialSupported(Boolean(serialApi));
  }, []);

  useEffect(() => {
    let isCancelled = false;

    const loadCount = async () => {
      try {
        const count = await getTelemetrySampleCount();
        if (!isCancelled) {
          setDatasetCount(count);
          setDatasetStatus(`Dataset ready (${count} samples)`);
        }
      } catch (error) {
        if (isCancelled) return;
        const message = error instanceof Error ? error.message : 'Failed to initialize dataset store.';
        setDatasetError(message);
        setDatasetStatus('Dataset unavailable');
      }
    };

    void loadCount();

    return () => {
      isCancelled = true;
    };
  }, []);

  useEffect(() => {
    const intervalId = window.setInterval(() => {
      void flushDatasetQueue();
    }, 1000);

    return () => {
      window.clearInterval(intervalId);
      void flushDatasetQueue();
    };
  }, [flushDatasetQueue]);

  useEffect(() => {
    isSimulatingRef.current = isSimulating;
  }, [isSimulating]);

  useEffect(() => {
    datasetSessionIdRef.current = datasetSessionId;
  }, [datasetSessionId]);

  useEffect(() => {
    datasetTrialIdRef.current = datasetTrialId;
  }, [datasetTrialId]);

  useEffect(() => {
    datasetDiseaseLabelRef.current = datasetDiseaseLabel;
  }, [datasetDiseaseLabel]);

  useEffect(() => {
    simModeRef.current = simMode;
  }, [simMode]);

  useEffect(() => {
    if (!wsData || isSimulating || isConnected) return;
    applyWsFrame(wsData as Record<string, unknown>);
  }, [applyWsFrame, isConnected, isSimulating, wsData]);

  useEffect(() => {
    if (isConnected || !wsLastMessageAt) return;
    setLastPacketAt(wsLastMessageAt);
  }, [isConnected, wsLastMessageAt]);

  // Real-time telemetry connection/simulation stream
  useEffect(() => {
    let demoTimer = 0;
    const modes: GaitMode[] = ['Normal', 'Parkinson', 'Stroke', 'Neuropathy', 'Foot Drop', 'Ataxia'];

    const interval = setInterval(() => {
      const tick = tickRef.current++;

      if (isSimulating) {
        if (isDemoMode) {
          demoTimer += 100;
          if (demoTimer >= 8000) {
            setSimMode(prev => {
              const curIndex = modes.indexOf(prev);
              return modes[(curIndex + 1) % modes.length];
            });
            demoTimer = 0;
          }
        }
        
        const frame = generateGaitFrame(simMode, Date.now());
        const simPitch = (Math.random() - 0.5) * frame.imuRollVariance * 10;
        const simRoll = (Math.random() - 0.5) * frame.imuRollVariance * 20;

        const simulationPacket: RawSensorPacket = {
          heel: frame.heel,
          inner: frame.mt1,
          outer: frame.mt5,
          toe: frame.toe,
          impact: frame.impact,
          pitch: simPitch,
          roll: simRoll,
          accZ: 9.81,
          timestampMs: Date.now(),
        };

        applyBiomechanicsPacket(simulationPacket);
        enqueueDatasetSample(simulationPacket, 'sim', 'simulation', simModeRef.current);

        setSimExplanation(frame.explanation);
        return;
        
      }

      if (isConnected || isWsConnected) {
        // Live mode data is streamed by the serial read loop.
        return;
      }

      // When disconnected and not simulating, settle charts back to baseline quietly.
      setSwayData((prev) => [...prev.slice(1), { time: tick, roll: 0, pitch: 0 }]);
      setImpactData((prev) => [...prev.slice(1), { time: tick, impact: 0 }]);
    }, 100);

    return () => clearInterval(interval);
  }, [applyBiomechanicsPacket, enqueueDatasetSample, isConnected, isSimulating, simMode, isDemoMode, isWsConnected]);

  useEffect(() => {
    return () => {
      void disconnectSerial();
    };
  }, [disconnectSerial]);

  const liveConnected = isConnected || isWsConnected;
  const linkLabel = isConnected ? 'ESP32 USB Linked' : (isWsConnected ? 'ESP32 WiFi Linked' : (isSimulating ? 'Simulation Active' : 'Edge Disconnected'));
  const linkStatus = isConnected ? serialStatus : (isWsConnected ? 'WebSocket Connected' : 'Offline');


  return (
    <div className="w-full relative mx-auto bg-[#F5F7FA] dark:bg-[#1A1D24] overflow-x-hidden min-h-screen pb-24 font-sans text-slate-900 dark:text-slate-100">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-[#F5F7FA]/90 dark:bg-[#1A1D24]/90 backdrop-blur-xl px-5 py-6 flex items-center justify-between transition-colors duration-300">
        <div>
           <h1 className="text-2xl font-extrabold tracking-tight text-[#1A1D24] dark:text-white">GaitGuard Nexus</h1>
           <div className="flex items-center gap-2 mt-1">
             <div className="flex h-2 w-2 relative">
               {liveConnected && <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>}
               <span className={`relative inline-flex rounded-full h-2 w-2 ${liveConnected ? 'bg-emerald-500' : 'bg-slate-400'}`}></span>
             </div>
             <span className="text-[10px] font-bold tracking-widest text-slate-500 uppercase">
              {linkLabel}
             </span>
           </div>
        </div>
        <div className="flex gap-2">
           <div className="flex flex-col items-end justify-center mr-2 hidden sm:flex">
             <span className="text-[9px] font-bold text-slate-400 uppercase tracking-widest">Data Link</span>
             <span className={`text-[11px] font-mono font-semibold ${liveConnected ? 'text-emerald-600 dark:text-emerald-400' : 'text-slate-500 dark:text-slate-500'}`}>{linkStatus}</span>
           </div>
           
           <div className="flex items-center">
             <ThemeSwitch />
           </div>

           {/* Interactive Connection Toggle */}
           <button 
             onClick={() => {
              if (isConnected) {
                void disconnectSerial();
                return;
              }
              void connectSerial();
             }}
             disabled={!isSerialSupported || isConnectingRef.current}
             className={`cursor-pointer size-9 rounded-full flex items-center justify-center border transition-all duration-300 hover:scale-105 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed ${isConnected ? 'bg-slate-100 dark:bg-slate-800 border-slate-200 dark:border-slate-700' : 'bg-rose-100 dark:bg-rose-900/30 border-rose-300 dark:border-rose-800'}`}
             title={isConnected ? 'Disconnect ESP32 USB serial' : 'Connect ESP32 USB serial'}
           >
             <span className={`material-symbols-outlined text-[18px] ${isConnected ? 'text-slate-600 dark:text-slate-300' : 'text-rose-500'}`}>{isConnected ? 'usb' : 'usb_off'}</span>
           </button>

           <Link to="/settings" className="size-9 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center overflow-hidden border border-slate-200 dark:border-slate-700 hover:opacity-80 transition-opacity">
             <img alt="User Profile" className="w-full h-full object-cover" data-alt="Portrait of a smiling user for profile icon" src="https://lh3.googleusercontent.com/aida-public/AB6AXuDOjAXRxkQH10k1EbLEzChoZEyu6YCuKmwx-we6whLkZIOkI4t2GzCnGlpqx5PnW6YoN9Gi1TglagU7ZJoPnCBBNXAWpXUeTI1PWyc8FI4_J4i4Qgyv-0YSo8s3zCa73jh3Jos3IuccVmF3jJgheMCHiHmuwvDnVP3cnYnsvlQhKh8wXF-wTeunYtV_edwLC5XWcR1X6wcZWICgq_nc6k9ILAvuwY_f2z-YOiIHVC91tI6vpXm4iHO93ZOqnBgTRsMft6ApSq3JKog"/>
           </Link>
        </div>
      </header>
      
      <main className="px-5 pt-5 space-y-5">
        {serialError && !isSimulating && (
          <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-rose-700 dark:border-rose-800/60 dark:bg-rose-950/30 dark:text-rose-300">
            <p className="text-xs font-bold uppercase tracking-wider">Serial Link Error</p>
            <p className="mt-1 text-xs leading-relaxed">{serialError}</p>
          </div>
        )}

        {wsError && !isSimulating && !isConnected && (
          <div className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-amber-800 dark:border-amber-800/60 dark:bg-amber-950/20 dark:text-amber-300">
            <p className="text-xs font-bold uppercase tracking-wider">WiFi Stream Status</p>
            <p className="mt-1 text-xs leading-relaxed">{wsError}</p>
            <p className="mt-1 text-[11px] opacity-80">Target: {wsUrl}</p>
          </div>
        )}

        {!isSerialSupported && !isSimulating && (
          <div className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-amber-800 dark:border-amber-800/60 dark:bg-amber-950/20 dark:text-amber-300">
            <p className="text-xs font-bold uppercase tracking-wider">Web Serial Not Available</p>
            <p className="mt-1 text-xs leading-relaxed">Open this dashboard in Microsoft Edge or Chrome on localhost to connect ESP32 over USB.</p>
          </div>
        )}

        {liveConnected && lastPacketAt && !isSimulating && (
          <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-emerald-700 dark:border-emerald-900/70 dark:bg-emerald-950/20 dark:text-emerald-300">
            <p className="text-xs font-bold uppercase tracking-wider">Live Telemetry Active</p>
            <p className="mt-1 text-xs leading-relaxed">Last packet: {new Date(lastPacketAt).toLocaleTimeString()}</p>
          </div>
        )}

        {!isSimulating && (
          <section className="rounded-2xl border border-slate-200 bg-white px-4 py-3 dark:border-slate-800 dark:bg-[#20252E]">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="text-[10px] font-bold uppercase tracking-widest text-slate-400">ESP32 Dataset Store</p>
                <p className="mt-1 text-sm font-extrabold text-slate-800 dark:text-slate-100">{datasetCount.toLocaleString()} samples</p>
                <p className="mt-1 text-[11px] text-slate-500 dark:text-slate-400">{datasetStatus}</p>
                {datasetSavedAt && (
                  <p className="mt-1 text-[11px] text-slate-400">Last write: {new Date(datasetSavedAt).toLocaleTimeString()}</p>
                )}
                {datasetError && (
                  <p className="mt-1 text-[11px] font-semibold text-rose-600 dark:text-rose-300">{datasetError}</p>
                )}
                <p className="mt-2 text-[11px] text-slate-500 dark:text-slate-400">Upload: {uploadStatus}</p>
                {uploadSuccessAt && (
                  <p className="mt-1 text-[11px] text-slate-400">Last upload: {new Date(uploadSuccessAt).toLocaleTimeString()}</p>
                )}
                {uploadError && (
                  <p className="mt-1 text-[11px] font-semibold text-rose-600 dark:text-rose-300">{uploadError}</p>
                )}
                <p className="mt-1 text-[11px] text-slate-400">Endpoint: {uploadEndpoint || 'not configured'}</p>
                <div className="mt-3 grid grid-cols-1 gap-2 sm:grid-cols-2">
                  <label className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
                    Session ID
                    <input
                      value={datasetSessionId}
                      onChange={(event) => setDatasetSessionId(event.target.value)}
                      className="mt-1 w-full rounded-lg border border-slate-200 bg-white px-2 py-1 text-[11px] font-semibold text-slate-700 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100"
                      placeholder="session-2026-03-14"
                    />
                  </label>
                  <label className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
                    Trial ID
                    <input
                      value={datasetTrialId}
                      onChange={(event) => setDatasetTrialId(event.target.value)}
                      className="mt-1 w-full rounded-lg border border-slate-200 bg-white px-2 py-1 text-[11px] font-semibold text-slate-700 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100"
                      placeholder="trial-001"
                    />
                  </label>
                  <label className="text-[10px] font-bold uppercase tracking-wider text-slate-400 sm:col-span-2">
                    Disease Label (Live Stream Tag)
                    <select
                      value={datasetDiseaseLabel}
                      onChange={(event) => setDatasetDiseaseLabel(event.target.value as DiseaseLabel)}
                      className="mt-1 w-full rounded-lg border border-slate-200 bg-white px-2 py-1 text-[11px] font-semibold text-slate-700 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100"
                    >
                      {DATASET_DISEASE_OPTIONS.map((label) => (
                        <option key={label} value={label}>{label}</option>
                      ))}
                    </select>
                  </label>
                </div>
              </div>
              <div className="flex flex-col gap-2">
                <button
                  onClick={() => void handleExportDataset()}
                  className="rounded-lg bg-[#415AEE] px-3 py-1.5 text-[11px] font-bold uppercase tracking-wider text-white"
                >
                  Export CSV
                </button>
                <button
                  onClick={() => void handleUploadDataset()}
                  disabled={isUploadingDataset}
                  className="rounded-lg bg-emerald-600 px-3 py-1.5 text-[11px] font-bold uppercase tracking-wider text-white disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isUploadingDataset ? 'Uploading...' : 'Upload'}
                </button>
                <button
                  onClick={() => void handleClearDataset()}
                  className="rounded-lg bg-slate-100 px-3 py-1.5 text-[11px] font-bold uppercase tracking-wider text-slate-600 dark:bg-slate-800 dark:text-slate-300"
                >
                  Clear
                </button>
              </div>
            </div>
          </section>
        )}

        {/* Connection / Simulation Mode Toggle */}
        <div className="flex justify-between items-center bg-white dark:bg-[#1A1D24] p-1.5 rounded-[24px] shadow-soft w-full border border-slate-100 dark:border-slate-800">
          <button 
            onClick={() => { setIsSimulating(false); setIsDemoMode(false); }}
            className={`flex-1 flex justify-center items-center gap-2 px-4 py-3 rounded-[20px] text-[11px] font-extrabold uppercase tracking-widest transition-all ${!isSimulating ? 'bg-[#F5F7FA] dark:bg-[#20252E] text-emerald-500 shadow-sm' : 'text-slate-400 hover:text-slate-600 dark:hover:text-slate-300'}`}
          >
            <span className="material-symbols-outlined text-[16px]">sensors</span>
            Live Sensor
          </button>
          <button 
            onClick={() => setIsSimulating(true)}
            className={`flex-1 flex justify-center items-center gap-2 px-4 py-3 rounded-[20px] text-[11px] font-extrabold uppercase tracking-widest transition-all ${isSimulating ? 'bg-[#415AEE] text-white shadow-[0_4px_12px_rgba(65,90,238,0.3)]' : 'text-slate-400 hover:text-slate-600 dark:hover:text-slate-300'}`}
          >
            <span className="material-symbols-outlined text-[16px]">science</span>
            Simulation
          </button>
        </div>

        {/* Explainable Alert Panel for Simulation */}
        {isSimulating && (
          <div className="animate-in slide-in-from-top-2 fade-in duration-300 bg-[#415AEE]/10 border border-[#415AEE]/20 dark:bg-[#415AEE]/10 dark:border-[#415AEE]/30 rounded-[28px] p-5 flex items-start gap-4 shadow-soft">
            <span className="material-symbols-outlined text-[#415AEE] mt-0.5 text-2xl" style={{ fontVariationSettings: "'FILL' 1" }}>psychology</span>
            <div className="flex-1">
              <p className="text-[13px] font-extrabold text-[#1A1D24] dark:text-white uppercase tracking-wider">{simMode} Gait Detected</p>
              <p className="text-[12px] text-[#415AEE] dark:text-[#415AEE]/80 font-bold mt-1.5 leading-relaxed tracking-wide">
                {simExplanation}
              </p>
            </div>
          </div>
        )}
        
        {/* Module 3: Recent Alert (Dynamic Banner) */}
        {isAlertVisible && !isSimulating && (
          <div className="animate-in slide-in-from-top-2 fade-in duration-300 bg-rose-50 border border-rose-200/60 dark:bg-rose-950/30 dark:border-rose-900/50 rounded-2xl p-4 flex items-start gap-3 shadow-sm relative overflow-hidden">
            <div className="absolute left-0 top-0 bottom-0 w-1 bg-rose-500"></div>
            <span className="material-symbols-outlined text-rose-500 fill-1 mt-0.5">warning</span>
            <div className="flex-1">
              <p className="text-sm font-bold text-rose-700 dark:text-rose-400">Ischemic Risk Avoidance</p>
              <p className="text-xs text-rose-600/80 dark:text-rose-300/80 font-medium mt-1 leading-relaxed">
                Time-Pressure Integral &gt; 50mmHg capillary occlusion threshold at 1st Metatarsal. Offload immediately.
              </p>
            </div>
            <button className="text-rose-400 hover:bg-rose-100 dark:hover:bg-rose-900/50 p-1 rounded-full transition-colors flex-shrink-0" onClick={() => setIsAlertVisible(false)}>
              <span className="material-symbols-outlined text-sm">close</span>
            </button>
          </div>
        )}

        {/* Top Dual Cards */}
        <div className="grid grid-cols-2 gap-4">
           {/* Ring Card with Recharts RadialBar */}
           <div className="bg-white dark:bg-[#20252E] rounded-[32px] p-4 shadow-soft flex flex-col items-center justify-center group cursor-pointer transition-transform hover:scale-[1.02]" title="Stability Index: Recalibrates every 20 steps">
              <div className="relative w-[130px] h-[130px] flex items-center justify-center">
                <ResponsiveContainer width="100%" height="100%">
                  <RadialBarChart
                    data={[{ name: "Stability", value: score, fill: (liveConnected || isSimulating) ? "#415AEE" : "#64748b" }]}
                    startAngle={90}
                    endAngle={-270}
                    innerRadius={45}
                    outerRadius={65}
                    barSize={12}
                  >
                    <PolarGrid
                      gridType="circle"
                      radialLines={false}
                      stroke="none"
                      className="first:fill-transparent last:fill-transparent"
                      polarRadius={[50, 45]}
                    />
                    <RadialBar 
                      dataKey="value" 
                      background={{ fill: 'currentColor', className: 'text-slate-100 dark:text-slate-800' }} 
                      cornerRadius={10} 
                    />
                    <PolarRadiusAxis tick={false} tickLine={false} axisLine={false}>
                      <Label
                        content={({ viewBox }) => {
                          if (viewBox && "cx" in viewBox && "cy" in viewBox) {
                            return (
                              <text
                                x={viewBox.cx}
                                y={viewBox.cy}
                                textAnchor="middle"
                                dominantBaseline="middle"
                              >
                                <tspan
                                  x={viewBox.cx}
                                  y={viewBox.cy}
                                  className={`fill-[#1A1D24] dark:fill-white text-3xl font-extrabold ${!(liveConnected || isSimulating) && 'opacity-50'}`}
                                >
                                  {score}
                                </tspan>
                                <tspan
                                  x={viewBox.cx}
                                  y={(viewBox.cy || 0) + 20}
                                  className={`fill-slate-400 text-[9px] font-bold uppercase tracking-widest ${!(liveConnected || isSimulating) && 'opacity-50'}`}
                                >
                                  Stability Idx
                                </tspan>
                              </text>
                            )
                          }
                        }}
                      />
                    </PolarRadiusAxis>
                  </RadialBarChart>
                </ResponsiveContainer>
              </div>
              <div className="mt-2 flex items-center gap-1.5 bg-emerald-50 dark:bg-emerald-500/10 px-2.5 py-1 rounded-full">
                <span className="material-symbols-outlined text-[14px] text-emerald-500 font-bold" style={{ fontVariationSettings: "'FILL' 1" }}>trending_up</span>
                <span className="text-[9px] font-bold text-emerald-600 dark:text-emerald-400 uppercase tracking-wider">+5.2%</span>
              </div>
           </div>

           {/* Metrics Column */}
           <div className="flex flex-col gap-3">
              <button onClick={() => setMlpi(0)} className="bg-white hover:bg-slate-50 dark:bg-[#20252E] dark:hover:bg-[#20252E]/80 transition-transform hover:scale-[1.02] rounded-[24px] p-4 shadow-soft flex-1 flex flex-col justify-center text-left" title="Click to Reset MLPI Baseline">
                 <div className="flex justify-between items-center w-full">
                    <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">MLPI Score</span>
                    <span className="material-symbols-outlined text-[14px] text-amber-500">balance</span>
                 </div>
                 <div className="flex items-end gap-1 mt-1 transition-all duration-300">
                    <span className={`text-xl font-extrabold pb-0.5 ${liveConnected ? 'text-slate-900 dark:text-white' : 'text-slate-400'}`}>{mlpi}</span>
                    <span className="text-[10px] text-slate-400 font-medium pb-1.5">Δ</span>
                 </div>
              </button>
              <div className="bg-white dark:bg-[#20252E] rounded-[24px] p-4 shadow-soft flex-1 flex flex-col justify-center cursor-help transition-transform hover:scale-[1.02]" title="Stance/Swing Ratio: Target is 60:40">
                 <div className="flex justify-between items-center">
                    <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">S/S Ratio</span>
                    <span className="material-symbols-outlined text-[14px] text-indigo-500">sync_alt</span>
                 </div>
                 <div className="flex items-end gap-1 mt-1">
                    <span className={`text-xl font-extrabold pb-0.5 ${(liveConnected || isSimulating) ? 'text-slate-900 dark:text-white' : 'text-slate-400'}`}>{stanceRatioStr}</span>
                 </div>
              </div>
           </div>
        </div>

        <section className="bg-white dark:bg-[#20252E] rounded-[32px] p-5 shadow-soft">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-bold text-slate-800 dark:text-slate-100">Biomechanics Engine</h2>
            <span className="px-2 py-0.5 bg-indigo-50 dark:bg-indigo-500/10 rounded text-[9px] font-bold uppercase tracking-wider text-indigo-600 dark:text-indigo-300">Buffer 50</span>
          </div>

          <div className="mt-4 grid grid-cols-2 gap-3">
            <div className="rounded-2xl border border-slate-200 dark:border-slate-700 p-3">
              <p className="text-[10px] uppercase tracking-widest font-bold text-slate-400">Gait Phase</p>
              <p className="mt-1 text-sm font-extrabold text-slate-800 dark:text-slate-100">{gaitPhase.replace('_', ' ')}</p>
            </div>
            <div className="rounded-2xl border border-slate-200 dark:border-slate-700 p-3">
              <p className="text-[10px] uppercase tracking-widest font-bold text-slate-400">Cadence</p>
              <p className="mt-1 text-sm font-extrabold text-slate-800 dark:text-slate-100">{cadenceSpm.toFixed(1)} spm</p>
            </div>
            <div className="rounded-2xl border border-slate-200 dark:border-slate-700 p-3">
              <p className="text-[10px] uppercase tracking-widest font-bold text-slate-400">Steps</p>
              <p className="mt-1 text-sm font-extrabold text-slate-800 dark:text-slate-100">{stepCount}</p>
            </div>
            <div className="rounded-2xl border border-slate-200 dark:border-slate-700 p-3">
              <p className="text-[10px] uppercase tracking-widest font-bold text-slate-400">Stability Band</p>
              <p className="mt-1 text-sm font-extrabold text-slate-800 dark:text-slate-100">{stabilityBand.toUpperCase()}</p>
            </div>
          </div>

          <div className="mt-4 grid grid-cols-2 gap-3">
            <div className="rounded-2xl border border-slate-200 dark:border-slate-700 p-3">
              <p className="text-[10px] uppercase tracking-widest font-bold text-slate-400">Impact Severity</p>
              <div className="mt-2 h-2 w-full rounded-full bg-slate-200 dark:bg-slate-800 overflow-hidden">
                <div className="h-full bg-orange-500 transition-all duration-300" style={{ width: `${Math.round(impactLevel * 100)}%` }}></div>
              </div>
              <p className="mt-1 text-[11px] font-semibold text-slate-600 dark:text-slate-300">{Math.round(impactLevel * 100)}%</p>
            </div>

            <div className="rounded-2xl border border-slate-200 dark:border-slate-700 p-3">
              <p className="text-[10px] uppercase tracking-widest font-bold text-slate-400">Center of Pressure</p>
              <div className="relative mt-2 h-24 rounded-xl bg-slate-100 dark:bg-slate-900 overflow-hidden">
                {copTrail.map((point, index) => (
                  <span
                    key={`cop-${index}`}
                    className="absolute h-1.5 w-1.5 -translate-x-1/2 -translate-y-1/2 rounded-full bg-indigo-300/80"
                    style={{ left: `${point.x * 100}%`, top: `${(1 - point.y) * 100}%` }}
                  ></span>
                ))}
                <span
                  className="absolute h-3 w-3 -translate-x-1/2 -translate-y-1/2 rounded-full bg-indigo-600 shadow-[0_0_0_4px_rgba(99,102,241,0.2)]"
                  style={{ left: `${copPoint.x * 100}%`, top: `${(1 - copPoint.y) * 100}%` }}
                ></span>
              </div>
            </div>
          </div>

          {anomalyFlags.length > 0 && (
            <div className="mt-4 rounded-2xl border border-rose-200 dark:border-rose-900/60 bg-rose-50 dark:bg-rose-950/20 p-3">
              <p className="text-[10px] font-bold uppercase tracking-widest text-rose-600 dark:text-rose-300">Anomaly Flags</p>
              <div className="mt-1.5 space-y-1">
                {anomalyFlags.map((flag) => (
                  <p key={flag} className="text-[11px] text-rose-700 dark:text-rose-200">{flag}</p>
                ))}
              </div>
            </div>
          )}
        </section>

        <DiseaseSelector 
           selected={simMode} 
           onSelect={setSimMode} 
           isSimulating={isSimulating} 
           onDemoToggle={() => setIsDemoMode(!isDemoMode)} 
           isDemoMode={isDemoMode}
        />

        {/* FSR Radar Chart & Orpyx Tracker */}
        <section className="bg-white dark:bg-[#20252E] rounded-[32px] p-6 shadow-soft">
           <div className="flex justify-between items-center mb-1">
             <h2 className="text-sm font-bold text-slate-800 dark:text-slate-100">FSR Spatial Distribution</h2>
             <button title="Toggle Calibration Mode" className="px-2 py-0.5 bg-blue-50 hover:bg-blue-100 dark:bg-blue-900/20 dark:hover:bg-blue-900/40 text-blue-600 dark:text-blue-400 rounded text-[9px] font-bold uppercase tracking-wider transition-colors">12-bit ADC</button>
           </div>
           
           <div className="flex flex-col gap-6 mt-3 relative">
              <div className="w-full max-w-sm mx-auto aspect-square relative cursor-crosshair drop-shadow-sm transition-all duration-300">
                  <FootHeatmap sensors={fsrData} isConnected={liveConnected || isSimulating} />
              </div>
              
              <div className="w-full cursor-pointer group px-1" onClick={() => setIntegral(0)} title="Click to manually clear Integral buffer">
                 <h3 className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2 group-hover:text-blue-500 transition-colors">Orpyx Rule Integrator</h3>
                 <div className="space-y-3">
                   <div>
                     <div className="flex justify-between text-[11px] font-semibold mb-1 transition-colors">
                       <span className="text-slate-600 dark:text-slate-300">Time-Pressure Int.</span>
                        <span className={integral > 50 ? "text-rose-500" : (liveConnected ? "text-emerald-500" : "text-slate-400")}>{integral.toFixed(0)}%</span>
                     </div>
                     <div className="h-1.5 w-full bg-slate-100 dark:bg-slate-800 rounded-full overflow-hidden">
                        <div className={`h-full transition-all duration-500 ${integral > 50 ? 'bg-rose-500' : (liveConnected ? 'bg-emerald-500' : 'bg-slate-400')}`} style={{ width: `${integral}%` }}></div>
                     </div>
                     <p className="text-[9px] text-slate-400 mt-1 leading-tight group-hover:text-slate-500 transition-colors">Capillary Occlusion Limit: 50mmHg &gt; 15m</p>
                   </div>
                 </div>
              </div>
           </div>
        </section>

        {/* Kinematic MPU6050 Chart */}
        <section className="bg-white dark:bg-[#20252E] rounded-[32px] p-6 shadow-soft">
           <div className="flex justify-between items-center mb-4">
             <div className="flex flex-col">
               <h2 className="text-sm font-bold text-slate-800 dark:text-slate-100">Ankle Kinematics</h2>
               <span className="text-[10px] font-semibold text-slate-400 hover:text-indigo-500 transition-colors cursor-help" title="MPU6050 6-Axis Accelerometer/Gyro">MPU6050 &bull; Medial Arch &bull; 100Hz</span>
             </div>
             <div className="flex items-center gap-3">
               <div className="flex items-center gap-1"><span className={`w-2 h-2 rounded-full ${liveConnected ? 'bg-indigo-500' : 'bg-slate-300'}`}></span><span className="text-[9px] font-bold text-slate-500">Roll</span></div>
               <div className="flex items-center gap-1"><span className={`w-2 h-2 rounded-full ${liveConnected ? 'bg-cyan-500' : 'bg-slate-300'}`}></span><span className="text-[9px] font-bold text-slate-500">Pitch</span></div>
             </div>
           </div>
           
           <div className="h-32 w-full -ml-4 cursor-crosshair">
             <ResponsiveContainer width="100%" height="100%">
               <LineChart data={swayData}>
                 <XAxis dataKey="time" hide />
                 <YAxis domain={[-20, 20]} hide />
                 <Tooltip contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.05)' }} labelStyle={{ display: 'none' }} />
                 <Line type="monotone" dataKey="roll" stroke={liveConnected ? "#6366f1" : "#cbd5e1"} strokeWidth={2} dot={false} isAnimationActive={false} />
                 <Line type="monotone" dataKey="pitch" stroke={liveConnected ? "#06b6d4" : "#cbd5e1"} strokeWidth={2} dot={false} isAnimationActive={false} />
               </LineChart>
             </ResponsiveContainer>
           </div>
        </section>
        
        {/* Piezo Impact Sharpness */}
        <section className="bg-white dark:bg-[#20252E] rounded-[32px] p-6 shadow-soft">
           <div className="flex justify-between items-center mb-4">
             <div className="flex flex-col">
               <h2 className="text-sm font-bold text-slate-800 dark:text-slate-100">Impact Sharpness</h2>
               <span className="text-[10px] font-semibold text-slate-400 hover:text-orange-500 transition-colors cursor-help" title="Detects shuffling mechanics">27mm Piezo &bull; T-stance Trigger</span>
             </div>
             <button title="Test Piezo Feedback" onClick={() => { if(liveConnected) setImpactData(prev => [...prev.slice(1), { time: 999, impact: 600 }]) }} className="material-symbols-outlined text-orange-500 hover:text-orange-600 transition-colors font-light active:scale-90">bolt</button>
           </div>
           
           <div className="h-28 w-full -ml-4 cursor-crosshair">
             <ResponsiveContainer width="100%" height="100%">
               <AreaChart data={impactData}>
                 <defs>
                   <linearGradient id="piezoGrad" x1="0" y1="0" x2="0" y2="1">
                     <stop offset="5%" stopColor={liveConnected ? "#f97316" : "#cbd5e1"} stopOpacity={0.3}/>
                     <stop offset="95%" stopColor={liveConnected ? "#f97316" : "#cbd5e1"} stopOpacity={0}/>
                   </linearGradient>
                 </defs>
                 <XAxis dataKey="time" hide />
                 <YAxis hide />
                 <Tooltip contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.05)' }} labelStyle={{ display: 'none' }} />
                 <Area type="monotone" dataKey="impact" stroke={liveConnected ? "#f97316" : "#94a3b8"} strokeWidth={2} fillOpacity={1} fill="url(#piezoGrad)" isAnimationActive={false} />
               </AreaChart>
             </ResponsiveContainer>
           </div>
        </section>

        {/* Edge Hardware Stats */}
        <section className="bg-slate-800 dark:bg-slate-900 border border-slate-700 dark:border-slate-800 rounded-2xl p-4 shadow-sm text-slate-300 flex items-center justify-between mb-4 mt-2">
           <div className="flex items-center gap-3">
             <span className={`material-symbols-outlined text-xl ${liveConnected ? 'text-slate-400' : 'text-slate-600'}`}>memory</span>
             <div>
               <p className="text-[10px] font-bold uppercase tracking-widest text-slate-500">Local Cache (LittleFS)</p>
               <p className={`text-xs font-mono mt-0.5 ${liveConnected ? 'text-slate-300' : 'text-slate-600'}`}>8.4 KB <span className="text-slate-500">/ 2 MB</span></p>
             </div>
           </div>
           <div className="flex items-center gap-3 border-l border-slate-700 pl-4">
             <span className={`material-symbols-outlined text-xl ${liveConnected ? 'text-emerald-400' : 'text-slate-600'}`}>charging_station</span>
             <div>
               <p className="text-[10px] font-bold uppercase tracking-widest text-slate-500">LiPo Reg</p>
               <p className={`text-xs font-mono mt-0.5 ${liveConnected ? 'text-slate-300' : 'text-slate-600'}`}>3.29V <span className="text-slate-500">LDO</span></p>
             </div>
           </div>
        </section>

      </main>
    </div>
  );
}
