import { Link } from 'react-router-dom';

export default function ClinicianPDFDark() {
  return (
    <div className="w-full relative mx-auto bg-white dark:bg-slate-900 overflow-x-hidden min-h-screen">
      {/* Top Navigation (Mobile/Web Header) */}
<div className="sticky top-0 z-30 bg-obsidian/80 backdrop-blur-md border-b border-white/10 px-4 py-3 flex items-center justify-between no-print">
<div className="flex items-center gap-3">
<span className="material-symbols-outlined text-primary">arrow_back</span>
<h1 className="text-lg font-semibold">Report Viewer</h1>
</div>
<div className="flex items-center gap-2">
<button className="p-2 rounded-full hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors">
<span className="material-symbols-outlined text-slate-600 dark:text-slate-400">share</span>
</button>
<button className="bg-primary text-white px-4 py-2 rounded-full text-sm font-medium flex items-center gap-2">
<span className="material-symbols-outlined text-sm">download</span>
                PDF
            </button>
</div>
</div>
{/* Main Report Canvas */}
<main className="max-w-4xl mx-auto mt-8 px-4 sm:px-6">
<div className="bg-surface print-container print-shadow rounded-xl overflow-hidden border border-white/5">
{/* Header Section */}
<header className="p-8 border-b border-white/5 bg-white/5">
<div className="flex flex-col md:flex-row justify-between items-start gap-6">
<div className="flex gap-5 items-center">
<div className="size-20 rounded-full bg-primary/10 flex items-center justify-center overflow-hidden border-2 border-white dark:border-slate-700 shadow-sm">
<img alt="Patient Avatar" className="w-full h-full object-cover" data-alt="Professional headshot of a middle-aged male patient" src="https://lh3.googleusercontent.com/aida-public/AB6AXuC5l37mLamSXnLwlXSLQM5dMHgr_590WSn8DKO5p110tOwcWxLINMpTrknTrVkW_fQnTUeHWXgPsA4eWnFqCae_D2bjigxaU_0_lozMug74kxmDTZC3D7la1G22jiTMgQ3MFduVyeYU_9oU8IPOz0oBS8efJiC-QS0i4sdq6jRvX_llBW6DvJYsjuOLi19G0DYqORm1MpatyGiT9vtcu-z26BIPqJk8NYswMFPc4jYs1ighO5CDNP0xWCSlPseygpRIA38Qm5Q0HMM"/>
</div>
<div>
<h2 className="text-2xl font-bold tracking-tight">Johnathan R. Doe</h2>
<p className="text-slate-400 text-sm font-medium">Patient ID: #GG-88291 • DOB: 05/12/1978</p>
<div className="flex items-center gap-2 mt-1">
<span className="size-2 rounded-full bg-emerald-500"></span>
<span className="text-xs font-semibold text-emerald-600 dark:text-emerald-400 uppercase tracking-wider">Active Monitoring</span>
</div>
</div>
</div>
<div className="text-left md:text-right">
<div className="text-primary font-bold text-xl mb-1 flex items-center md:justify-end gap-2">
<span className="material-symbols-outlined">analytics</span>
                            GaitGuard Nexus
                        </div>
<p className="text-slate-400 text-sm font-medium">Report Date: Oct 24, 2023</p>
<p className="text-slate-400 text-sm font-medium">Period: Last 30 Days</p>
</div>
</div>
</header>
{/* 1. Clinical Summary */}
<section className="p-8">
<div className="flex items-center gap-2 mb-4">
<span className="material-symbols-outlined text-primary">description</span>
<h3 className="text-lg font-bold">Clinical Summary</h3>
</div>
<div className="bg-white/5 rounded-xl p-6 border-l-4 border-primary">
<p className="text-slate-200 leading-relaxed">
                        Patient exhibits a <span className="font-bold text-primary">4.2% improvement</span> in gait symmetry over the last 30-day monitoring window. Stability indices remain robust within the 85th percentile, indicating a statistically low fall risk. Recommended: Continued observation of peak pressure on the left metatarsal during prolonged ambulation. Overall progress is consistent with physical therapy objectives.
                    </p>
</div>
</section>
{/* 2. Gait Symmetry & Stability */}
<section className="px-8 pb-8">
<div className="grid grid-cols-1 md:grid-cols-2 gap-8">
<div>
<div className="flex items-center justify-between mb-4">
<h3 className="text-sm font-bold uppercase tracking-widest text-slate-500">Gait Symmetry Trend</h3>
<span className="text-emerald-500 text-sm font-bold">+2.1%</span>
</div>
<div className="h-48 w-full bg-white/5 rounded-lg p-4 flex items-end justify-between gap-1 relative overflow-hidden">
{/* Minimalist Line Chart Representation */}
<div className="absolute inset-0 flex items-center justify-center opacity-10">
<span className="material-symbols-outlined text-[120px]">show_chart</span>
</div>
<div className="w-2 bg-primary/20 rounded-t-full h-[40%]"></div>
<div className="w-2 bg-primary/20 rounded-t-full h-[45%]"></div>
<div className="w-2 bg-primary/40 rounded-t-full h-[55%]"></div>
<div className="w-2 bg-primary/40 rounded-t-full h-[50%]"></div>
<div className="w-2 bg-primary/60 rounded-t-full h-[65%]"></div>
<div className="w-2 bg-primary/80 rounded-t-full h-[75%]"></div>
<div className="w-2 bg-primary rounded-t-full h-[85%]"></div>
</div>
<div className="flex justify-between mt-2 text-[10px] text-slate-400 font-medium px-1">
<span>WK 1</span><span>WK 2</span><span>WK 3</span><span>WK 4</span>
</div>
</div>
<div>
<div className="flex items-center justify-between mb-4">
<h3 className="text-sm font-bold uppercase tracking-widest text-slate-500">Stability Index</h3>
<span className="text-primary text-sm font-bold">92/100</span>
</div>
<div className="h-48 w-full bg-white/5 rounded-lg p-4 flex items-end justify-between gap-1 relative overflow-hidden">
<svg className="size-32 transform -rotate-90">
<circle className="text-slate-200 dark:text-slate-700" cx="64" cy="64" fill="transparent" r="58" stroke="currentColor" strokeWidth="8" />
<circle className="text-primary" cx="64" cy="64" fill="transparent" r="58" stroke="currentColor" strokeDasharray="364.4" strokeDashoffset="29" strokeWidth="8" />
</svg>
<div className="absolute inset-0 flex flex-col items-center justify-center">
<span className="text-2xl font-bold">92%</span>
<span className="text-[10px] text-slate-400">OPTIMAL</span>
</div>
</div>
<div className="flex justify-between mt-2 text-[10px] text-slate-400 font-medium px-1">
<span>LOW RISK</span><span>MED RISK</span><span>HIGH RISK</span>
</div>
</div>
</div>
</section>
{/* 3. Pressure Distribution */}
<section className="p-8 border-t border-white/5">
<div className="flex items-center gap-2 mb-6">
<span className="material-symbols-outlined text-primary">do_not_step</span>
<h3 className="text-lg font-bold">Pressure Distribution (Avg.)</h3>
</div>
<div className="flex flex-col md:flex-row items-center justify-around gap-12 py-4">
<div className="relative">
<p className="text-center text-[10px] font-bold text-slate-400 mb-4 uppercase tracking-widest">Left Foot</p>
<div className="w-32 h-64 bg-white/5 rounded-[3rem] relative overflow-hidden border border-white/10">
{/* Heel Pressure */}
<div className="absolute bottom-4 left-1/2 -translate-x-1/2 size-16 rounded-full bg-orange-500/40 blur-xl"></div>
{/* Midsole */}
<div className="absolute top-1/2 left-1/2 -translate-x-1/2 size-12 rounded-full bg-emerald-500/20 blur-lg"></div>
{/* Metatarsal (High pressure) */}
<div className="absolute top-12 left-1/2 -translate-x-1/2 size-14 rounded-full bg-red-500/60 blur-xl"></div>
</div>
</div>
<div className="flex flex-col gap-3">
<div className="flex items-center gap-3">
<div className="size-3 rounded-full bg-red-500"></div>
<span className="text-xs font-medium text-slate-600 dark:text-slate-400">Peak (90+ N/cm²)</span>
</div>
<div className="flex items-center gap-3">
<div className="size-3 rounded-full bg-orange-500"></div>
<span className="text-xs font-medium text-slate-600 dark:text-slate-400">Elevated (60-90 N/cm²)</span>
</div>
<div className="flex items-center gap-3">
<div className="size-3 rounded-full bg-emerald-500"></div>
<span className="text-xs font-medium text-slate-600 dark:text-slate-400">Nominal (&lt;60 N/cm²)</span>
</div>
</div>
<div className="relative">
<p className="text-center text-[10px] font-bold text-slate-400 mb-4 uppercase tracking-widest">Right Foot</p>
<div className="w-32 h-64 bg-white/5 rounded-[3rem] relative overflow-hidden border border-white/10">
{/* Heel Pressure */}
<div className="absolute bottom-4 left-1/2 -translate-x-1/2 size-16 rounded-full bg-orange-500/30 blur-xl"></div>
{/* Midsole */}
<div className="absolute top-1/2 left-1/2 -translate-x-1/2 size-12 rounded-full bg-emerald-500/30 blur-lg"></div>
{/* Metatarsal */}
<div className="absolute top-12 left-1/2 -translate-x-1/2 size-14 rounded-full bg-orange-500/50 blur-xl"></div>
</div>
</div>
</div>
</section>
{/* 4. Metric Table */}
<section className="p-8 bg-white/5">
<div className="flex items-center gap-2 mb-6">
<span className="material-symbols-outlined text-primary">table_chart</span>
<h3 className="text-lg font-bold">Biometric Metrics</h3>
</div>
<div className="overflow-hidden rounded-xl border border-white/10 bg-surface">
<table className="w-full text-left border-collapse">
<thead>
<tr className="bg-white/5">
<th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase">Metric</th>
<th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase">Avg. Value</th>
<th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase">Normal Range</th>
<th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase">Status</th>
</tr>
</thead>
<tbody className="divide-y divide-slate-100 dark:divide-slate-800">
<tr>
<td className="px-6 py-4 text-sm font-semibold">Cadence</td>
<td className="px-6 py-4 text-sm font-mono">112 steps/min</td>
<td className="px-6 py-4 text-sm text-slate-400 font-mono">100 - 120</td>
<td className="px-6 py-4">
<span className="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400 uppercase">Normal</span>
</td>
</tr>
<tr>
<td className="px-6 py-4 text-sm font-semibold">Step Count (Daily)</td>
<td className="px-6 py-4 text-sm font-mono">8,432</td>
<td className="px-6 py-4 text-sm text-slate-400 font-mono">7,000 - 10,000</td>
<td className="px-6 py-4">
<span className="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400 uppercase">Normal</span>
</td>
</tr>
<tr>
<td className="px-6 py-4 text-sm font-semibold">Peak Pressure</td>
<td className="px-6 py-4 text-sm font-mono">94.2 N/cm²</td>
<td className="px-6 py-4 text-sm text-slate-400 font-mono">40 - 85</td>
<td className="px-6 py-4">
<span className="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400 uppercase">Elevated</span>
</td>
</tr>
<tr>
<td className="px-6 py-4 text-sm font-semibold">Stride Length</td>
<td className="px-6 py-4 text-sm font-mono">0.74 m</td>
<td className="px-6 py-4 text-sm text-slate-400 font-mono">0.70 - 0.82</td>
<td className="px-6 py-4">
<span className="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400 uppercase">Normal</span>
</td>
</tr>
</tbody>
</table>
</div>
</section>
{/* Footer Section */}
<footer className="p-8 border-t border-white/5 text-center">
<p className="text-[10px] text-slate-400 uppercase tracking-[0.2em] font-medium mb-4">CONFIDENTIAL MEDICAL RECORD - GENERATED BY GAITGUARD NEXUS AI</p>
<div className="flex flex-col sm:flex-row justify-center gap-4 no-print">
<button className="flex items-center justify-center gap-2 bg-primary hover:bg-primary/90 text-white font-bold py-3 px-8 rounded-full transition-all shadow-lg shadow-primary/25">
<span className="material-symbols-outlined">download</span>
                        Download PDF Report
                    </button>
<button className="flex items-center justify-center gap-2 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 font-bold py-3 px-8 rounded-full transition-all">
<span className="material-symbols-outlined">send</span>
                        Share with Clinician
                    </button>
</div>
</footer>
</div>
</main>
{/* Bottom Navigation Bar (App Experience) */}
<div className="fixed bottom-0 left-0 right-0 bg-obsidian/95 backdrop-blur-xl border-t border-white/10 px-6 py-3 flex justify-between items-center z-40 no-print">
<Link to="#" className="flex flex-col items-center gap-1 text-primary">
<span className="material-symbols-outlined">assignment</span>
<span className="text-[10px] font-bold">Reports</span>
</Link>
<Link to="#" className="flex flex-col items-center gap-1 text-slate-400">
<span className="material-symbols-outlined">group</span>
<span className="text-[10px] font-bold">Patients</span>
</Link>
<Link to="#" className="flex flex-col items-center gap-1 text-slate-400">
<span className="material-symbols-outlined">monitoring</span>
<span className="text-[10px] font-bold">Analysis</span>
</Link>
<Link to="#" className="flex flex-col items-center gap-1 text-slate-400">
<span className="material-symbols-outlined">settings</span>
<span className="text-[10px] font-bold">Settings</span>
</Link>
</div>
    </div>
  );
}
