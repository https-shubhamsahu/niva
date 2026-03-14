import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import ThemeSwitch from '../components/ThemeSwitch';

export default function TrendAnalytics() {
  const [activeTab, setActiveTab] = useState('Week');

  return (
    <div className="w-full relative mx-auto bg-[#F5F7FA] dark:bg-[#1A1D24] overflow-x-hidden min-h-screen font-sans text-slate-900 dark:text-slate-100 pb-24">
      {/* Header Section */}
      <header className="sticky top-0 z-50 bg-[#F5F7FA]/90 dark:bg-[#1A1D24]/90 backdrop-blur-md pb-1 transition-colors">
        <div className="flex items-center justify-between px-5 py-4">
          <div className="flex items-center gap-3">
            <div className="size-10 overflow-hidden rounded-lg bg-primary/10 flex items-center justify-center">
              <img alt="Niva brand logo" className="w-8 h-8 object-contain" src="https://lh3.googleusercontent.com/aida-public/AB6AXuDq-rzcKZlc8mqq3FUpExvqVBeX-2gBY6FQ1Pqd_2wOCUuyReMPcmeWkuo1lTPtgOgjYn-JMZK2iYUn0xA_Oa6qSql-k9PGL3v21PYaS918Zh7MHP8WdSiWtXtfqz2NB3weJ5coza-aAoRVBALRZLR9SJaQIRanMnHcxbcdpqFBo9JodAS_b7iKNXxrn0ghRGBiP-BVO_pqWyVRiKTuJXhyTHF-QD8ndIkf_ICazKf_Rvug8e7QiqcpzoDWGwH_S0O0S2f4-kfhdqM"/>
            </div>
            <div>
              <h1 className="text-xl font-extrabold tracking-tight text-[#1A1D24] dark:text-white">GaitGuard Nexus</h1>
              <p className="text-[10px] uppercase tracking-widest text-[#415AEE] font-bold">Trend Analysis</p>
            </div>
          </div>
          <div className="flex items-center gap-4">
            <ThemeSwitch />
            <button className="flex size-10 items-center justify-center rounded-full bg-slate-100 dark:bg-[#20252E] text-slate-600 dark:text-slate-300 hover:bg-slate-200 transition-colors shadow-sm">
              <span className="material-symbols-outlined text-[20px]">calendar_month</span>
            </button>
          </div>
        </div>

        {/* Navigation Tabs */}
        <div className="px-5 pb-3 mt-1">
          <div className="flex p-1.5 bg-white dark:bg-[#20252E] shadow-soft rounded-[24px]">
            <Link to="/main" className="flex-1 py-2 text-center text-[11px] font-bold text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 transition-colors uppercase tracking-wider">Live View</Link>
            <button className="flex-1 py-2 text-[11px] font-bold bg-[#415AEE] text-white shadow-md rounded-[20px] uppercase tracking-wider">Analysis</button>
            <Link to="/insights" className="flex-1 py-2 text-center text-[11px] font-bold text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 transition-colors uppercase tracking-wider">Insights</Link>
          </div>
        </div>
      </header>

      <main className="flex-1 px-5 pt-6 space-y-5">
        
        {/* Time Segmented Control */}
        <div className="flex p-1.5 bg-white dark:bg-[#20252E] rounded-full shadow-soft border border-slate-100 dark:border-slate-800">
          {['Week', 'Month', 'Year'].map(tab => (
             <button 
               key={tab}
               onClick={() => setActiveTab(tab)}
               className={`flex-1 py-2 text-[11px] font-extrabold rounded-full transition-all uppercase tracking-widest ${activeTab === tab ? 'bg-[#F5F7FA] dark:bg-[#1A1D24] text-[#1A1D24] dark:text-white shadow-sm' : 'text-slate-400 hover:text-slate-600 dark:hover:text-slate-300'}`}
             >
               {tab}
             </button>
          ))}
        </div>

        {/* Clinical Summary */}
        <section className="p-5 bg-[#415AEE]/10 dark:bg-[#415AEE]/10 rounded-[28px] border border-[#415AEE]/20 shadow-soft">
          <div className="flex items-start gap-4">
            <span className="material-symbols-outlined text-[#415AEE] mt-0.5 text-2xl" style={{ fontVariationSettings: "'FILL' 1" }}>insights</span>
            <div>
              <h3 className="text-[13px] font-extrabold text-[#1A1D24] dark:text-white uppercase tracking-wider">Clinical Summary</h3>
              <p className="text-[12px] font-medium text-[#415AEE] dark:text-[#415AEE]/80 mt-1.5 leading-relaxed tracking-wide">
                Your gait symmetry has improved by <span className="font-extrabold">4%</span> this {activeTab.toLowerCase()}. Step stability remains consistent despite increased daily cadence.
              </p>
            </div>
          </div>
        </section>

        {/* Gait Symmetry Card */}
        <section className="p-5 bg-white dark:bg-[#20252E] shadow-soft rounded-[32px]">
          <div className="flex justify-between items-start mb-4">
            <div>
              <h2 className="text-[10px] font-extrabold text-slate-400 uppercase tracking-widest">Gait Symmetry</h2>
              <div className="flex items-end gap-2 mt-1">
                <p className="text-3xl font-extrabold text-[#1A1D24] dark:text-white">94%</p>
                <div className="flex items-center gap-1 text-emerald-500 bg-emerald-50 dark:bg-emerald-500/10 px-2 py-0.5 rounded-full w-fit mb-1 border border-emerald-500/20">
                  <span className="text-[10px] font-bold">+2%</span>
                </div>
              </div>
            </div>
          </div>
          <div className="h-40 w-full relative">
            <svg className="w-full h-full" preserveAspectRatio="none" viewBox="0 0 400 150">
              <defs>
                <linearGradient id="blueGradient" x1="0" x2="0" y1="0" y2="1">
                  <stop offset="0%" stopColor="#415AEE" stopOpacity="0.4"></stop>
                  <stop offset="100%" stopColor="#415AEE" stopOpacity="0"></stop>
                </linearGradient>
              </defs>
              <path d="M0 110 C 50 110, 100 20, 150 20 C 200 20, 250 80, 300 80 C 350 80, 375 40, 400 40 V 150 H 0 Z" fill="url(#blueGradient)" />
              <path d="M0 110 C 50 110, 100 20, 150 20 C 200 20, 250 80, 300 80 C 350 80, 375 40, 400 40" fill="none" stroke="#415AEE" strokeLinecap="round" strokeWidth="4" />
            </svg>
            <div className="flex justify-between mt-3 px-1 text-[10px] font-bold text-slate-400 uppercase tracking-widest">
              <span>Mon</span><span>Tue</span><span>Wed</span><span>Thu</span><span>Fri</span><span>Sat</span><span>Sun</span>
            </div>
          </div>
        </section>

        {/* Step Stability Card */}
        <section className="p-5 bg-white dark:bg-[#20252E] shadow-soft rounded-[32px]">
          <div className="flex justify-between items-start mb-6">
            <div>
              <h2 className="text-[10px] font-extrabold text-slate-400 uppercase tracking-widest">Step Stability</h2>
              <p className="text-3xl font-extrabold mt-1 text-[#1A1D24] dark:text-white">88<span className="text-sm text-slate-400 font-bold ml-1">/100</span></p>
            </div>
            <div className="flex items-center gap-1 text-[#FF4D4D] bg-[#FF4D4D]/10 px-2 py-0.5 rounded-full w-fit mt-1 border border-[#FF4D4D]/20">
              <span className="text-[10px] font-bold">-1%</span>
            </div>
          </div>
          <div className="flex items-end justify-between gap-3 h-32 px-1">
            <div className="flex-1 bg-[#415AEE]/20 dark:bg-[#415AEE]/30 rounded-t-lg" style={{ height: '80%' }}></div>
            <div className="flex-1 bg-[#415AEE]/20 dark:bg-[#415AEE]/30 rounded-t-lg" style={{ height: '45%' }}></div>
            <div className="flex-1 bg-[#415AEE]/20 dark:bg-[#415AEE]/30 rounded-t-lg" style={{ height: '95%' }}></div>
            <div className="flex-1 bg-[#415AEE]/20 dark:bg-[#415AEE]/30 rounded-t-lg" style={{ height: '70%' }}></div>
            <div className="flex-1 bg-[#415AEE]/20 dark:bg-[#415AEE]/30 rounded-t-lg" style={{ height: '60%' }}></div>
            <div className="flex-1 bg-[#415AEE]/20 dark:bg-[#415AEE]/30 rounded-t-lg" style={{ height: '85%' }}></div>
            <div className="flex-1 bg-[#415AEE] rounded-t-lg shadow-[0_0_15px_rgba(65,90,238,0.5)]" style={{ height: '88%' }}></div>
          </div>
        </section>

        {/* Cadence & Pressure Row */}
        <div className="grid grid-cols-2 gap-4 pb-6">
          <section className="p-5 bg-white dark:bg-[#20252E] shadow-soft rounded-[28px] flex flex-col justify-between">
            <div>
              <h2 className="text-[10px] font-extrabold text-slate-400 uppercase tracking-widest">Avg Cadence</h2>
              <p className="text-2xl font-extrabold mt-1 text-[#1A1D24] dark:text-white">112 <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">spm</span></p>
            </div>
            <div className="h-16 mt-4 w-full flex items-end">
              <svg className="w-full h-full overflow-visible" viewBox="0 0 100 30" preserveAspectRatio="none">
                <path d="M0 20 L 20 15 L 40 25 L 60 10 L 80 18 L 100 5" fill="none" stroke="#415AEE" strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" />
              </svg>
            </div>
          </section>
          
          <section className="p-5 bg-white dark:bg-[#20252E] shadow-soft rounded-[28px] flex flex-col justify-between">
            <div>
              <h2 className="text-[10px] font-extrabold text-slate-400 uppercase tracking-widest">Peak Pressure</h2>
              <p className="text-2xl font-extrabold mt-1 text-[#FF4D4D]">4.2 <span className="text-[11px] font-bold text-[#FF4D4D]/60 uppercase tracking-wider">kPa</span></p>
            </div>
            <div className="h-16 mt-4 w-full flex items-end">
              <svg className="w-full h-full overflow-visible" viewBox="0 0 100 30" preserveAspectRatio="none">
                <path d="M0 5 L 25 15 L 50 10 L 75 25 L 100 20" fill="none" stroke="#FF4D4D" strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" />
              </svg>
            </div>
          </section>
        </div>

      </main>
    </div>
  );
}
