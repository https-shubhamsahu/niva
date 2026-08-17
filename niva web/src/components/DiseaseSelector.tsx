import type { GaitMode } from '../utils/simulationEngine';

interface Props {
  selected: GaitMode;
  onSelect: (mode: GaitMode) => void;
  isSimulating: boolean;
  onDemoToggle: () => void;
  isDemoMode: boolean;
}

export default function DiseaseSelector({ selected, onSelect, isSimulating, onDemoToggle, isDemoMode }: Props) {
  const modes: GaitMode[] = ['Normal', 'Parkinson', 'Stroke', 'Neuropathy', 'Foot Drop', 'Ataxia'];

  if (!isSimulating) return null;

  return (
    <div className="flex flex-col gap-3 w-full bg-white dark:bg-[#20252E] p-5 rounded-[24px] shadow-soft transition-all duration-300">
       <div className="flex justify-between items-center">
         <h3 className="text-[13px] font-extrabold text-[#1A1D24] dark:text-white uppercase tracking-wide">Disease Simulation Engine</h3>
         <button 
           onClick={onDemoToggle}
           className={`px-3 py-1.5 rounded-full text-[10px] font-heavy uppercase tracking-widest flex items-center gap-1 transition-colors ${isDemoMode ? 'bg-[#FF4D4D] text-white shadow-[0_0_15px_rgba(255,77,77,0.3)]' : 'bg-[#F5F7FA] dark:bg-[#1A1D24] text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'}`}
         >
           <span className="material-symbols-outlined text-[14px]" style={{ fontVariationSettings: "'FILL' 1" }}>{isDemoMode ? 'stop_circle' : 'play_circle'}</span>
           {isDemoMode ? 'Stop Demo' : 'Run Clinical Demo'}
         </button>
       </div>
       <div className="flex flex-wrap gap-2">
         {modes.map(mode => (
           <button
             key={mode}
             onClick={() => {
               if (!isDemoMode) onSelect(mode);
             }}
             className={`px-4 py-2 rounded-full text-[11px] font-bold tracking-wider transition-all disabled:opacity-50 ${selected === mode ? 'bg-[#415AEE] text-white shadow-[0_4px_12px_rgba(65,90,238,0.3)]' : 'bg-[#e8ebfd] text-[#415AEE] hover:bg-[#d0d6fb] dark:bg-[#1A1D24] dark:text-slate-400 dark:hover:text-slate-200'} ${isDemoMode && selected !== mode ? 'opacity-50 cursor-not-allowed' : ''}`}
           >
             {mode}
           </button>
         ))}
       </div>
    </div>
  );
}
