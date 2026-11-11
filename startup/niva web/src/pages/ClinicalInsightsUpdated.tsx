import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import FootHeatmap from '../components/FootHeatmap';
import ThemeSwitch from '../components/ThemeSwitch';

export default function ClinicalInsightsUpdated() {
  const feetImageSrc = `${import.meta.env.BASE_URL}feet.png`;
  const [viewMode, setViewMode] = useState<'3d' | 'anatomy' | 'heatmap'>('3d');
  const [showCritical, setShowCritical] = useState(true);
  const [showWarning, setShowWarning] = useState(true);
  
  const [symmetry, setSymmetry] = useState(94.0);
  const [peak, setPeak] = useState(142);
  const [sensors, setSensors] = useState([
    { sensor: 'Heel', val: 95 },
    { sensor: '1st Met', val: 82 },
    { sensor: '5th Met', val: 35 },
    { sensor: 'Hallux', val: 20 },
  ]);

  useEffect(() => {
    if (viewMode !== 'heatmap' && viewMode !== '3d') return;
    const interval = setInterval(() => {
      setSensors(prev => prev.map(s => ({
        ...s,
        val: Math.max(10, Math.min(100, s.val + (Math.random() - 0.5) * 15))
      })));
      setSymmetry(prev => Math.max(90, Math.min(100, prev + (Math.random() > 0.5 ? 0.2 : -0.2))));
      setPeak(prev => Math.max(130, Math.min(160, prev + (Math.random() > 0.5 ? 2 : -2))));
    }, 1000);
    return () => clearInterval(interval);
  }, [viewMode]);

  return (
    <div className="w-full relative mx-auto bg-[#F5F7FA] dark:bg-[#1A1D24] overflow-x-hidden min-h-screen">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-[#F5F7FA]/90 dark:bg-[#1A1D24]/90 backdrop-blur-md pb-1 transition-colors">
        <div className="flex items-center justify-between px-5 py-4">
          <div className="flex items-center gap-3">
            <div className="size-10 overflow-hidden rounded-lg bg-primary/10 flex items-center justify-center">
              <img alt="Niva brand logo" className="w-8 h-8 object-contain" src="https://lh3.googleusercontent.com/aida-public/AB6AXuDq-rzcKZlc8mqq3FUpExvqVBeX-2gBY6FQ1Pqd_2wOCUuyReMPcmeWkuo1lTPtgOgjYn-JMZK2iYUn0xA_Oa6qSql-k9PGL3v21PYaS918Zh7MHP8WdSiWtXtfqz2NB3weJ5coza-aAoRVBALRZLR9SJaQIRanMnHcxbcdpqFBo9JodAS_b7iKNXxrn0ghRGBiP-BVO_pqWyVRiKTuJXhyTHF-QD8ndIkf_ICazKf_Rvug8e7QiqcpzoDWGwH_S0O0S2f4-kfhdqM"/>
            </div>
            <div>
              <h1 className="text-xl font-extrabold tracking-tight text-[#1A1D24] dark:text-white">GaitGuard Nexus</h1>
              <p className="text-[10px] uppercase tracking-widest text-[#415AEE] font-bold">Clinical Suite</p>
            </div>
          </div>
          <div className="flex items-center gap-4">
            <ThemeSwitch />
            <button onClick={() => alert('All clinical notifications are caught up.')} className="flex size-10 items-center justify-center rounded-full bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-200 transition-colors">
              <span className="material-symbols-outlined text-[22px]">notifications</span>
            </button>
          </div>
        </div>
        
        {/* Segmented Control / Tabs */}
        <div className="px-5 pb-3 mt-1">
          <div className="flex p-1.5 bg-white dark:bg-[#20252E] shadow-soft rounded-[24px]">
            <Link to="/main" className="flex-1 py-2 text-center text-[11px] font-bold text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 transition-colors uppercase tracking-wider">Live View</Link>
            <Link to="/trends" className="flex-1 py-2 text-center text-[11px] font-bold text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 transition-colors uppercase tracking-wider">Analysis</Link>
            <button className="flex-1 py-2 text-[11px] font-bold bg-[#415AEE] text-white shadow-md rounded-[20px] uppercase tracking-wider">Insights</button>
          </div>
        </div>
      </header>
      
      <main className="pb-32">
        {/* Summary Stats */}
        <div className="px-5 pt-6 grid grid-cols-2 gap-4">
          <div className="p-5 bg-white dark:bg-[#20252E] shadow-soft rounded-[28px] flex flex-col justify-center transition-transform hover:scale-[1.02]">
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Gait Symmetry</p>
            <p className="text-3xl font-extrabold text-[#1A1D24] dark:text-white mt-1">{symmetry.toFixed(1)}%</p>
            <div className="mt-2 flex items-center gap-1 text-emerald-500 bg-emerald-50 dark:bg-emerald-500/10 px-2 py-0.5 rounded-full w-fit">
              <span className="material-symbols-outlined text-[10px] font-bold">trending_up</span>
            </div>
          </div>
          <div className="p-5 bg-white dark:bg-[#20252E] shadow-soft rounded-[28px] flex flex-col justify-center transition-transform hover:scale-[1.02]">
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Peak Pressure</p>
            <p className="text-3xl font-extrabold text-[#FF4D4D] mt-1">{peak.toFixed(0)}<span className="text-[11px] font-bold text-[#FF4D4D]/60 ml-1 tracking-widest uppercase">kPa</span></p>
            <div className="mt-2 flex items-center gap-1 text-[#FF4D4D] bg-[#FF4D4D]/10 px-2 py-0.5 rounded-full w-fit">
              <span className="material-symbols-outlined text-[10px] font-bold">warning</span>
            </div>
          </div>
        </div>

        {/* Visualization Card */}
        <section className="px-5 pt-8">
          <div className="relative bg-white dark:bg-[#20252E] rounded-[32px] shadow-soft overflow-hidden">
            <div className="p-5 flex justify-between items-center z-10 relative">
              <h2 className="text-[13px] font-extrabold text-[#1A1D24] dark:text-white flex items-center gap-2 tracking-wide">
                <span className="material-symbols-outlined text-[#415AEE] text-xl">view_in_ar</span>
                Spatial Map
              </h2>
              <div className="flex items-center gap-2">
                <div className="flex p-1 bg-[#F5F7FA] dark:bg-[#1A1D24] rounded-full shadow-inner">
                  <button onClick={() => setViewMode('3d')} className={`px-3 py-1.5 text-[10px] font-extrabold uppercase tracking-widest rounded-full transition-all ${viewMode === '3d' ? 'bg-[#415AEE] shadow-md text-white' : 'text-slate-400 hover:text-slate-600'}`}>3D</button>
                  <button onClick={() => setViewMode('anatomy')} className={`px-3 py-1.5 text-[10px] font-extrabold uppercase tracking-widest rounded-full transition-all ${viewMode === 'anatomy' ? 'bg-[#415AEE] shadow-md text-white' : 'text-slate-400 hover:text-slate-600'}`}>Body</button>
                  <button onClick={() => setViewMode('heatmap')} className={`px-3 py-1.5 text-[10px] font-extrabold uppercase tracking-widest rounded-full transition-all ${viewMode === 'heatmap' ? 'bg-[#415AEE] shadow-md text-white' : 'text-slate-400 hover:text-slate-600'}`}>Map</button>
                </div>
              </div>
            </div>

            {/* Embed Container */}
            <div className="aspect-[4/5] w-full bg-[#FAFBFF] dark:bg-[#15181E] relative overflow-hidden flex items-center justify-center border-t border-[#F5F7FA] dark:border-white/5">
              {viewMode === '3d' && (
                <iframe allow="autoplay; fullscreen; vr" allowFullScreen className="w-full h-full border-0" src="https://sketchfab.com/models/c3c0acb84bb2432381e739bfaee843c3/embed?autostart=1&amp;camera=0&amp;preload=1&amp;transparent=1" title="3D Foot Model"></iframe>
              )}
              {viewMode === 'anatomy' && (
                <img src={feetImageSrc} alt="Anatomy" className="w-full h-full object-contain p-4 opacity-40 transition-opacity duration-300 pointer-events-none" style={{ filter: 'grayscale(0.8)' }} />
              )}
              {viewMode === 'heatmap' && (
                <div className="w-full h-full p-4 flex items-center justify-center overflow-hidden">
                  <div className="w-full h-full max-w-sm mx-auto flex items-center justify-center pb-8 scale-110">
                    <FootHeatmap sensors={sensors} isConnected={true} />
                  </div>
                </div>
              )}

              {/* Floating Insight Annotations */}
              {showCritical && (
                <div className="absolute top-8 right-4 max-w-[140px] p-3 bg-white/95 dark:bg-slate-800/95 backdrop-blur-md border-l-4 border-rose-500 rounded-r-lg shadow-lg">
                  <button className="absolute top-1.5 right-1.5 text-slate-400 hover:text-slate-600 transition-colors" onClick={() => setShowCritical(false)}>
                    <span className="material-symbols-outlined text-[12px]">close</span>
                  </button>
                  <p className="text-[10px] font-bold text-rose-500 uppercase flex items-center gap-1"><span className="material-symbols-outlined text-[12px]">warning</span> Alert</p>
                  <p className="text-[11px] font-semibold text-slate-800 dark:text-slate-100 mt-1">Peak Pressure: Right Heel</p>
                </div>
              )}
              
              {showWarning && (
                <div className="absolute bottom-12 left-4 max-w-[140px] p-3 bg-white/95 dark:bg-slate-800/95 backdrop-blur-md border-l-4 border-amber-500 rounded-r-lg shadow-lg">
                  <button className="absolute top-1.5 right-1.5 text-slate-400 hover:text-slate-600 transition-colors" onClick={() => setShowWarning(false)}>
                    <span className="material-symbols-outlined text-[12px]">close</span>
                  </button>
                  <p className="text-[10px] font-bold text-amber-500 uppercase flex items-center gap-1"><span className="material-symbols-outlined text-[12px]">info</span> Warning</p>
                  <p className="text-[11px] font-semibold text-slate-800 dark:text-slate-100 mt-1">Shear Force: 1st Metatarsal</p>
                </div>
              )}
            </div>

            {/* Legends */}
            <div className="p-5 bg-white shrink-0 dark:bg-[#20252E] z-10 relative">
              <div className="flex flex-col gap-4 w-full">
                <div className="flex justify-between items-center px-2">
                  <div className="flex flex-col items-center gap-1.5"><div className="size-3 rounded-full bg-[#FF4D4D] shadow-[0_0_12px_rgba(255,77,77,0.5)]"></div><span className="text-[9px] font-bold text-slate-400 uppercase tracking-widest text-center leading-tight">High<br/>Pressure</span></div>
                  <div className="h-6 w-px bg-slate-200 dark:bg-slate-700"></div>
                  <div className="flex flex-col items-center gap-1.5"><div className="size-3 rounded-full bg-amber-400 shadow-[0_0_12px_rgba(251,191,36,0.5)]"></div><span className="text-[9px] font-bold text-slate-400 uppercase tracking-widest text-center leading-tight">Warn<br/>Elevated</span></div>
                  <div className="h-6 w-px bg-slate-200 dark:bg-slate-700"></div>
                  <div className="flex flex-col items-center gap-1.5"><div className="size-3 rounded-full bg-[#415AEE] shadow-[0_0_12px_rgba(65,90,238,0.5)]"></div><span className="text-[9px] font-bold text-slate-400 uppercase tracking-widest text-center leading-tight">Ideal<br/>Optimal</span></div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* Detailed Observations */}
        <section className="px-5 pt-8">
          <h3 className="text-[14px] font-extrabold text-[#1A1D24] dark:text-white mb-5 uppercase tracking-wide">Automated Observations</h3>
          <div className="space-y-4">
            <div onClick={() => { setShowCritical(true); alert("Pronation Overload details expanded."); }} className="p-5 bg-white dark:bg-[#20252E] rounded-[24px] flex gap-4 shadow-soft hover:shadow-md hover:-translate-y-1 transition-all duration-300 cursor-pointer group">
              <div className="size-12 rounded-full bg-[#FF4D4D]/10 flex items-center justify-center shrink-0 group-hover:bg-[#FF4D4D] transition-colors">
                <span className="material-symbols-outlined text-[#FF4D4D] group-hover:text-white">priority_high</span>
              </div>
              <div className="flex flex-col justify-center">
                <h4 className="text-[13px] font-extrabold text-[#1A1D24] dark:text-white group-hover:text-[#FF4D4D] transition-colors">Pronation Overload</h4>
                <p className="text-[11px] font-medium text-slate-500 mt-1 leading-relaxed">Excessive medial roll detected mid-stance phase. Recommend orthotics.</p>
              </div>
            </div>
            <div onClick={() => alert("Cadence stability metrics logged.")} className="p-5 bg-white dark:bg-[#20252E] rounded-[24px] flex gap-4 shadow-soft hover:shadow-md hover:-translate-y-1 transition-all duration-300 cursor-pointer group">
              <div className="size-12 rounded-full bg-emerald-500/10 flex items-center justify-center shrink-0 group-hover:bg-emerald-500 transition-colors">
                <span className="material-symbols-outlined text-emerald-500 group-hover:text-white">check_circle</span>
              </div>
              <div className="flex flex-col justify-center">
                <h4 className="text-[13px] font-extrabold text-[#1A1D24] dark:text-white group-hover:text-emerald-500 transition-colors">Cadence Stability</h4>
                <p className="text-[11px] font-medium text-slate-500 mt-1 leading-relaxed">Rhythm remains consistent at 104 SPM. No deviations in temporal parameters.</p>
              </div>
            </div>
          </div>
        </section>
      </main>
    </div>
  );
}
