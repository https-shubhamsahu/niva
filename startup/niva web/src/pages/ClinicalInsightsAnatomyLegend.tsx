export default function ClinicalInsightsAnatomyLegend() {
  return (
    <div className="w-full relative mx-auto bg-white dark:bg-slate-900 overflow-x-hidden min-h-screen">
      {/* Header */}
<header className="sticky top-0 z-50 bg-white/80 dark:bg-background-dark/80 backdrop-blur-md border-b border-slate-100 dark:border-slate-800">
<div className="flex items-center justify-between px-5 py-4">
<div className="flex items-center gap-3">
<div className="size-10 overflow-hidden rounded-lg bg-primary/10 flex items-center justify-center">
<img alt="Niva brand logo professional clinical style" className="w-8 h-8 object-contain" data-alt="Niva brand logo professional clinical style" src="https://lh3.googleusercontent.com/aida-public/AB6AXuDq-rzcKZlc8mqq3FUpExvqVBeX-2gBY6FQ1Pqd_2wOCUuyReMPcmeWkuo1lTPtgOgjYn-JMZK2iYUn0xA_Oa6qSql-k9PGL3v21PYaS918Zh7MHP8WdSiWtXtfqz2NB3weJ5coza-aAoRVBALRZLR9SJaQIRanMnHcxbcdpqFBo9JodAS_b7iKNXxrn0ghRGBiP-BVO_pqWyVRiKTuJXhyTHF-QD8ndIkf_ICazKf_Rvug8e7QiqcpzoDWGwH_S0O0S2f4-kfhdqM"/>
</div>
<div>
<h1 className="text-lg font-bold tracking-tight text-slate-900 dark:text-white">GaitGuard Nexus</h1>
<p className="text-[10px] uppercase tracking-widest text-slate-400 font-semibold">Clinical Suite</p>
</div>
</div>
<button className="flex size-10 items-center justify-center rounded-full bg-system-gray dark:bg-slate-800 text-slate-600 dark:text-slate-300">
<span className="material-symbols-outlined text-[22px]">notifications</span>
</button>
</div>
{/* Segmented Control / Tabs */}
<div className="px-5 pb-3">
<div className="flex p-1 bg-system-gray dark:bg-slate-800 rounded-xl">
<button className="flex-1 py-1.5 text-xs font-semibold text-slate-500">Live View</button>
<button className="flex-1 py-1.5 text-xs font-semibold text-slate-500">Analysis</button>
<button className="flex-1 py-1.5 text-xs font-semibold bg-white dark:bg-slate-700 text-primary shadow-sm rounded-lg">Clinical Insights</button>
</div>
</div>
</header>
<main className="pb-32">
{/* Summary Stats */}
<div className="px-5 pt-6 grid grid-cols-2 gap-4">
<div className="p-4 bg-system-gray dark:bg-slate-800 rounded-xl">
<p className="text-[11px] font-light text-slate-500 dark:text-slate-400 uppercase tracking-wider">Gait Symmetry</p>
<p className="text-2xl font-bold text-slate-900 dark:text-white">94%</p>
<div className="mt-1 flex items-center gap-1 text-emerald-500">
<span className="material-symbols-outlined text-xs">trending_up</span>
<span className="text-[10px] font-bold">+2.4%</span>
</div>
</div>
<div className="p-4 bg-system-gray dark:bg-slate-800 rounded-xl">
<p className="text-[11px] font-light text-slate-500 dark:text-slate-400 uppercase tracking-wider">Peak Pressure</p>
<p className="text-2xl font-bold text-system-red">142<span className="text-xs font-normal text-slate-400 ml-1">kPa</span></p>
<div className="mt-1 flex items-center gap-1 text-system-red">
<span className="material-symbols-outlined text-xs">warning</span>
<span className="text-[10px] font-bold">Critical</span>
</div>
</div>
</div>
{/* 3D Visualization Card */}
<section className="px-5 pt-6">
<div className="relative bg-white dark:bg-slate-900 rounded-xl shadow-xl shadow-slate-200/50 dark:shadow-none border border-slate-100 dark:border-slate-800 overflow-hidden">
<div className="p-4 flex justify-between items-center border-b border-slate-50 dark:border-slate-800">
<h2 className="text-sm font-bold text-slate-800 dark:text-slate-200 flex items-center gap-2">
<span className="material-symbols-outlined text-primary text-lg">view_in_ar</span>
                        Spatial Distribution
                    </h2>
<div className="flex items-center gap-3">
<span className="px-2 py-1 bg-primary/10 text-primary text-[10px] font-bold rounded-md uppercase">3D Model</span>
<div className="flex p-0.5 bg-slate-100 dark:bg-slate-800 rounded-lg shadow-inner">
<button className="px-2.5 py-1 text-[10px] font-bold bg-white dark:bg-slate-700 text-slate-900 dark:text-white rounded-md shadow-sm">Anatomy</button>
<button className="px-2.5 py-1 text-[10px] font-bold text-slate-500 dark:text-slate-400">Heatmap</button>
</div>
</div>
</div>
{/* 3D Model Embed Container */}
<div className="aspect-[4/5] w-full bg-slate-50 dark:bg-slate-950 relative">
<iframe allow="autoplay; fullscreen; vr" allowFullScreen className="w-full h-full border-0" src="https://sketchfab.com/models/c3c0acb84bb2432381e739bfaee843c3/embed?autostart=1&amp;camera=0&amp;preload=1" title="3D Foot Model">
</iframe>
{/* Floating Insight Annotations */}
<div className="absolute top-8 right-4 max-w-[140px] p-3 bg-white/90 dark:bg-slate-800/90 backdrop-blur border-l-4 border-system-red rounded-r-lg shadow-lg">
<p className="text-[10px] font-bold text-system-red uppercase">Critical Alert</p>
<p className="text-[11px] font-semibold text-slate-800 dark:text-slate-100">Peak Pressure: Right Heel</p>
</div>
<div className="absolute bottom-12 left-4 max-w-[140px] p-3 bg-white/90 dark:bg-slate-800/90 backdrop-blur border-l-4 border-system-orange rounded-r-lg shadow-lg">
<p className="text-[10px] font-bold text-system-orange uppercase">Warning</p>
<p className="text-[11px] font-semibold text-slate-800 dark:text-slate-100">Shear Force: 1st Metatarsal</p>
</div>
<div className="absolute inset-0 pointer-events-none bg-gradient-to-tr from-system-red/5 via-transparent to-system-orange/5 opacity-0 transition-opacity duration-300" id="heatmap-overlay"></div></div>
<div className="p-4 bg-slate-50 dark:bg-slate-800/50 flex justify-center gap-6"><div className="flex flex-col gap-3 w-full">
{/* Heatmap Legend */}
<div className="flex flex-wrap justify-center gap-x-6 gap-y-2 pb-2 border-b border-slate-200/50 dark:border-slate-700/50">
<div className="flex items-center gap-1.5">
<div className="size-2 rounded-full bg-system-red"></div>
<span className="text-[10px] font-medium text-slate-500 dark:text-slate-400 uppercase tracking-tight">High Pressure</span>
</div>
<div className="flex items-center gap-1.5">
<div className="size-2 rounded-full bg-system-orange"></div>
<span className="text-[10px] font-medium text-slate-500 dark:text-slate-400 uppercase tracking-tight">Elevated</span>
</div>
<div className="flex items-center gap-1.5">
<div className="size-2 rounded-full bg-primary"></div>
<span className="text-[10px] font-medium text-slate-500 dark:text-slate-400 uppercase tracking-tight">Optimal</span>
</div>
</div>
{/* Anatomical Markers Legend */}
<div className="flex flex-wrap justify-center gap-x-6 gap-y-2">
<div className="flex items-center gap-1.5">
<span className="material-symbols-outlined text-[14px] text-system-red">location_on</span>
<span className="text-[10px] font-semibold text-slate-700 dark:text-slate-300">Peak Pressure</span>
</div>
<div className="flex items-center gap-1.5">
<span className="material-symbols-outlined text-[14px] text-system-orange">warning</span>
<span className="text-[10px] font-semibold text-slate-700 dark:text-slate-300">Shear Force</span>
</div>
<div className="flex items-center gap-1.5">
<span className="material-symbols-outlined text-[14px] text-emerald-500">check_circle</span>
<span className="text-[10px] font-semibold text-slate-700 dark:text-slate-300">Safe Zone</span>
</div>
</div>
</div></div>
</div>
</section>
{/* Detailed Observations */}
<section className="px-5 pt-8">
<h3 className="text-base font-bold text-slate-900 dark:text-white mb-4">Clinical Observations</h3>
<div className="space-y-4">
<div className="p-4 bg-white dark:bg-slate-900 rounded-xl border border-slate-100 dark:border-slate-800 flex gap-4 shadow-sm">
<div className="size-10 rounded-full bg-system-red/10 flex items-center justify-center shrink-0">
<span className="material-symbols-outlined text-system-red">priority_high</span>
</div>
<div>
<h4 className="text-sm font-bold text-slate-900 dark:text-white">Pronation Overload</h4>
<p className="text-xs text-slate-500 dark:text-slate-400 mt-1 leading-relaxed">Excessive medial roll detected during mid-stance phase. Recommend corrective orthotic adjustment.</p>
</div>
</div>
<div className="p-4 bg-white dark:bg-slate-900 rounded-xl border border-slate-100 dark:border-slate-800 flex gap-4 shadow-sm">
<div className="size-10 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
<span className="material-symbols-outlined text-primary">check_circle</span>
</div>
<div>
<h4 className="text-sm font-bold text-slate-900 dark:text-white">Cadence Stability</h4>
<p className="text-xs text-slate-500 dark:text-slate-400 mt-1 leading-relaxed">Rhythm remains consistent at 104 steps/min. No significant deviations in temporal parameters.</p>
</div>
</div>
</div>
</section>
</main>

    </div>
  );
}
