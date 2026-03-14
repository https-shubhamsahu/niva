import React from 'react';

export default function ClinicalInsights() {
  return (
    <div className="w-full relative mx-auto bg-white dark:bg-slate-900 overflow-x-hidden min-h-screen">
      <div className="max-w-md mx-auto bg-white dark:bg-slate-900 min-h-screen shadow-2xl flex flex-col relative overflow-hidden">
{/* Header */}
<header className="flex items-center justify-between p-4 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md sticky top-0 z-10 border-b border-slate-100 dark:border-slate-800">
<button className="size-10 flex items-center justify-center rounded-full hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors">
<span className="material-symbols-outlined">arrow_back_ios_new</span>
</button>
<h1 className="text-lg font-bold tracking-tight">Clinical Insights</h1>
<button className="size-10 flex items-center justify-center rounded-full hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors text-primary">
<span className="material-symbols-outlined">info</span>
</button>
</header>
<main className="flex-1 overflow-y-auto pb-32">
{/* Date/Patient Info */}
<div className="px-6 pt-6 pb-2">
<p className="text-xs font-bold text-primary uppercase tracking-widest">Live Monitoring</p>
<h2 className="text-2xl font-bold mt-1">Pressure Distribution</h2>
</div>
{/* Module 1: Clinical Pressure Map */}
<div className="px-4 py-4">
<div className="relative w-full aspect-[4/5] bg-slate-50 dark:bg-slate-800/50 rounded-xl flex items-center justify-center overflow-hidden border border-slate-100 dark:border-slate-800">
{/* Foot Outlines (Simulated via SVG with Gradients) */}
<div className="relative w-full h-full p-8 flex justify-around items-center">
{/* Left Foot */}
<div className="w-1/3 h-4/5 rounded-full opacity-40 blur-xl bg-gradient-to-b from-green-400 via-blue-400 to-blue-500"></div>
{/* Right Foot */}
<div className="w-1/3 h-4/5 rounded-full relative flex flex-col">
{/* Background soft map */}
<div className="absolute inset-0 rounded-full opacity-40 blur-xl bg-gradient-to-b from-green-400 via-blue-400 to-blue-500"></div>
{/* Amber Pulse on Heel */}
<div className="absolute bottom-4 left-1/2 -translate-x-1/2 size-12 rounded-full bg-amber-400/80 blur-lg animate-pulse"></div>
<div className="absolute bottom-7 left-1/2 -translate-x-1/2 size-4 rounded-full bg-amber-500 shadow-[0_0_15px_rgba(245,158,11,0.8)]"></div>
</div>
</div>
{/* Legend */}
<div className="absolute bottom-4 right-4 flex flex-col gap-1">
<div className="flex items-center gap-2 text-[10px] font-semibold text-slate-500">
<span className="size-2 rounded-full bg-amber-500"></span> HIGH
                        </div>
<div className="flex items-center gap-2 text-[10px] font-semibold text-slate-500">
<span className="size-2 rounded-full bg-blue-400"></span> NORMAL
                        </div>
</div>
</div>
</div>
{/* Module 2: Insights Card */}
<div className="px-4 py-2">
<div className="p-5 bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-100 dark:border-slate-700">
<div className="flex items-center gap-3 mb-3">
<div className="p-2 bg-amber-100 dark:bg-amber-900/30 rounded-lg text-amber-600 dark:text-amber-400">
<span className="material-symbols-outlined text-lg">warning</span>
</div>
<h3 className="font-bold text-lg">Heel Pressure Insight</h3>
</div>
<p className="text-slate-600 dark:text-slate-400 text-sm leading-relaxed">
                        The amber highlight indicates a <span className="text-amber-600 dark:text-amber-400 font-bold">15% increase</span> in right heel pressure over the last 2 hours. This sustained focal load exceeds recommended limits for tissue health.
                    </p>
<button className="mt-4 w-full py-2 bg-primary/10 text-primary font-semibold text-sm rounded-lg hover:bg-primary/20 transition-colors">
                        View Detailed Trends
                    </button>
</div>
</div>
{/* Module 3: Shear Force Bar */}
<div className="px-4 py-4">
<div className="p-5 bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-100 dark:border-slate-700">
<div className="flex justify-between items-end mb-4">
<div>
<p className="text-xs font-bold text-slate-400 uppercase tracking-tight">Kinematics</p>
<h3 className="font-bold text-base">Shear &amp; Friction</h3>
</div>
<span className="text-xs font-bold text-green-600 dark:text-green-400 bg-green-100 dark:bg-green-900/30 px-2 py-0.5 rounded-full">NORMAL</span>
</div>
<div className="relative h-2 w-full bg-slate-100 dark:bg-slate-700 rounded-full overflow-hidden mb-2">
{/* Zones Gradient */}
<div className="absolute inset-0 bg-gradient-to-r from-green-400 via-yellow-400 to-red-500 opacity-30"></div>
{/* Marker */}
<div className="absolute left-[30%] top-0 bottom-0 w-1 bg-slate-900 dark:bg-white rounded-full z-10"></div>
</div>
<div className="flex justify-between text-[10px] font-bold text-slate-400 uppercase">
<span>Low Risk</span>
<span>Moderate</span>
<span>Critical</span>
</div>
</div>
</div>
{/* Large System Button */}
<div className="px-4 py-6">
<button className="w-full bg-primary py-4 px-6 rounded-xl text-white font-bold flex items-center justify-center gap-3 shadow-lg shadow-primary/25 active:scale-95 transition-transform">
<span className="material-symbols-outlined">medical_information</span>
                    Share Medical ID &amp; Data
                </button>
<p className="text-center text-[10px] text-slate-400 mt-4 px-8">
                    Data is encrypted and shared only with verified clinical providers via HealthKit Secure Sync.
                </p>
</div>
</main>

{/* Background subtle elements for visual depth */}
<div className="absolute -top-24 -right-24 size-64 bg-primary/5 rounded-full blur-3xl pointer-events-none"></div>
</div>
    </div>
  );
}
