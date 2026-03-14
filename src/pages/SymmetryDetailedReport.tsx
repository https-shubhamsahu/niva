import React from 'react';

export default function SymmetryDetailedReport() {
  return (
    <div className="w-full relative mx-auto bg-white dark:bg-slate-900 overflow-x-hidden min-h-screen">
      {/* Header */}
<header className="sticky top-0 z-50 bg-background-light/80 dark:bg-background-dark/80 backdrop-blur-md px-4 py-4 border-b border-slate-200 dark:border-slate-800">
<div className="flex items-center justify-between max-w-lg mx-auto w-full">
<button className="flex items-center justify-center size-10 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-900 dark:text-slate-100">
<span className="material-symbols-outlined">arrow_back</span>
</button>
<h1 className="text-lg font-bold">Symmetry Report</h1>
<button className="flex items-center justify-center size-10 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-900 dark:text-slate-100">
<span className="material-symbols-outlined">more_horiz</span>
</button>
</div>
</header>
<main className="max-w-lg mx-auto px-4 pt-6 space-y-6">
{/* Hero Section */}
<section className="bg-white dark:bg-slate-900 rounded-[20px] p-8 shadow-sm border border-slate-100 dark:border-slate-800 text-center relative overflow-hidden">
<div className="absolute top-0 right-0 p-4">
<span className="inline-flex items-center gap-1 px-3 py-1 rounded-full bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400 text-xs font-bold uppercase tracking-wider">
<span className="size-2 bg-green-500 rounded-full animate-pulse"></span>
                    Normal
                </span>
</div>
<p className="text-slate-500 dark:text-slate-400 text-sm font-medium mb-1">Overall Symmetry Score</p>
<h2 className="text-6xl font-black text-slate-900 dark:text-white mb-2">94%</h2>
<div className="flex items-center justify-center gap-1.5 text-green-600 dark:text-green-400 font-semibold">
<span className="material-symbols-outlined text-lg">trending_up</span>
<span>7% better than last month</span>
</div>
</section>
{/* Primary Chart Section */}
<section className="bg-white dark:bg-slate-900 rounded-[20px] p-6 shadow-sm border border-slate-100 dark:border-slate-800">
<div className="flex justify-between items-end mb-6">
<div>
<h3 className="text-base font-bold">Pressure Distribution</h3>
<p className="text-sm text-slate-500">Left vs. Right Foot (24h)</p>
</div>
<div className="flex gap-4">
<div className="flex items-center gap-1.5">
<span className="size-3 rounded-full bg-primary"></span>
<span className="text-xs font-medium text-slate-500">Left</span>
</div>
<div className="flex items-center gap-1.5">
<span className="size-3 rounded-full bg-purple-500"></span>
<span className="text-xs font-medium text-slate-500">Right</span>
</div>
</div>
</div>
<div className="relative h-48 w-full mb-4">
<svg className="w-full h-full preserve-3d" viewBox="0 0 400 150">
{/* Right Foot Area (Purple) */}
<path d="M0 120 Q 50 110, 100 130 T 200 100 T 300 140 T 400 110 V 150 H 0 Z" fill="rgba(168, 85, 247, 0.15)" />
<path d="M0 120 Q 50 110, 100 130 T 200 100 T 300 140 T 400 110" fill="none" stroke="#a855f7" strokeLinecap="round" strokeWidth="3" />
{/* Left Foot Area (Blue) */}
<path d="M0 100 Q 50 80, 100 90 T 200 70 T 300 110 T 400 80 V 150 H 0 Z" fill="rgba(0, 123, 255, 0.15)" />
<path d="M0 100 Q 50 80, 100 90 T 200 70 T 300 110 T 400 80" fill="none" stroke="#007bff" strokeLinecap="round" strokeWidth="3" />
</svg>
</div>
<div className="flex justify-between text-[10px] font-bold text-slate-400 px-1 uppercase tracking-widest">
<span>00:00</span>
<span>06:00</span>
<span>12:00</span>
<span>18:00</span>
<span>23:59</span>
</div>
</section>
{/* Clinical Breakdown */}
<section className="space-y-4">
<h3 className="text-lg font-bold px-1">Clinical Breakdown</h3>
<div className="grid grid-cols-1 gap-3">
{/* Heel Strike */}
<div className="bg-white dark:bg-slate-900 rounded-xl p-4 flex items-center justify-between border border-slate-100 dark:border-slate-800">
<div className="flex items-center gap-4">
<div className="size-12 rounded-full bg-blue-50 dark:bg-blue-900/20 flex items-center justify-center text-blue-600 dark:text-blue-400">
<span className="material-symbols-outlined">footprint</span>
</div>
<div>
<p className="text-sm font-bold">Initial Contact</p>
<p className="text-xs text-slate-500">Heel Strike Symmetry</p>
</div>
</div>
<div className="text-right">
<p className="text-lg font-bold">96%</p>
<p className="text-[10px] text-green-500 font-bold">OPTIMAL</p>
</div>
</div>
{/* Mid-stance */}
<div className="bg-white dark:bg-slate-900 rounded-xl p-4 flex items-center justify-between border border-slate-100 dark:border-slate-800">
<div className="flex items-center gap-4">
<div className="size-12 rounded-full bg-purple-50 dark:bg-purple-900/20 flex items-center justify-center text-purple-600 dark:text-purple-400">
<span className="material-symbols-outlined">analytics</span>
</div>
<div>
<p className="text-sm font-bold">Mid-stance</p>
<p className="text-xs text-slate-500">Arch Loading Profile</p>
</div>
</div>
<div className="text-right">
<p className="text-lg font-bold">91%</p>
<p className="text-[10px] text-amber-500 font-bold">SLIGHT DEVIATION</p>
</div>
</div>
{/* Terminal Stance */}
<div className="bg-white dark:bg-slate-900 rounded-xl p-4 flex items-center justify-between border border-slate-100 dark:border-slate-800">
<div className="flex items-center gap-4">
<div className="size-12 rounded-full bg-primary/10 flex items-center justify-center text-primary">
<span className="material-symbols-outlined">directions_run</span>
</div>
<div>
<p className="text-sm font-bold">Terminal Stance</p>
<p className="text-xs text-slate-500">Toe-off Power Distribution</p>
</div>
</div>
<div className="text-right">
<p className="text-lg font-bold">95%</p>
<p className="text-[10px] text-green-500 font-bold">OPTIMAL</p>
</div>
</div>
</div>
</section>
{/* Symmetry Insights */}
<section className="bg-primary/5 dark:bg-primary/10 rounded-[20px] p-6 border border-primary/10">
<div className="flex items-center gap-2 mb-3 text-primary">
<span className="material-symbols-outlined font-variation-fill">lightbulb</span>
<h3 className="font-bold">Symmetry Insights</h3>
</div>
<p className="text-sm leading-relaxed text-slate-700 dark:text-slate-300">
                Your right side is bearing <span className="font-bold text-primary">4% more load</span> than your left, likely due to your recent ankle strain. This compensation is decreasing, showing positive recovery trends compared to last week.
            </p>
</section>
{/* Actions */}
<div className="pt-4 pb-8">
<button className="w-full bg-primary hover:bg-primary/90 text-white font-bold py-4 rounded-xl flex items-center justify-center gap-2 transition-colors">
<span className="material-symbols-outlined">picture_as_pdf</span>
                Share Report with Clinician
            </button>
</div>
</main>

    </div>
  );
}
