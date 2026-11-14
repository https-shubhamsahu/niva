import { Link } from 'react-router-dom';
import ThemeSwitch from '../components/ThemeSwitch';

type NoDeviceDataProps = {
  title: string;
};

// Honest placeholder for routes that used to show invented values (random-walk pressure,
// a sample patient report, fixed trend numbers). Nothing on this page is computed from a device
// yet; live readings are on the dashboard.
export default function NoDeviceData({ title }: NoDeviceDataProps) {
  return (
    <div className="w-full relative mx-auto bg-[#F5F7FA] dark:bg-[#1A1D24] overflow-x-hidden min-h-screen font-sans text-slate-900 dark:text-slate-100 pb-24">
      <header className="sticky top-0 z-50 bg-[#F5F7FA]/90 dark:bg-[#1A1D24]/90 backdrop-blur-md px-5 py-4 flex items-center justify-between">
        <div>
          <h1 className="text-xl font-extrabold tracking-tight text-[#1A1D24] dark:text-white">GaitGuard Nexus</h1>
          <p className="text-[10px] uppercase tracking-widest text-[#415AEE] font-bold">{title}</p>
        </div>
        <ThemeSwitch />
      </header>

      <main className="px-5 pt-6">
        <section className="p-6 bg-white dark:bg-[#20252E] rounded-[28px] shadow-soft">
          <span className="material-symbols-outlined text-slate-400 text-3xl">sensors_off</span>
          <h2 className="mt-3 text-lg font-extrabold text-[#1A1D24] dark:text-white">No device data yet</h2>
          <p className="mt-2 text-sm leading-relaxed text-slate-600 dark:text-slate-300">
            This view has nothing recorded to show. Live readings from the insole, or a clearly labelled
            simulation, are on the dashboard.
          </p>
          <p className="mt-2 text-xs leading-relaxed text-slate-500 dark:text-slate-400">
            Uncalibrated sensor readings. Not a medical device.
          </p>
          <Link
            to="/main"
            className="mt-5 inline-flex items-center gap-2 rounded-full bg-[#415AEE] px-4 py-2 text-[11px] font-extrabold uppercase tracking-widest text-white"
          >
            <span className="material-symbols-outlined text-[16px]">grid_view</span>
            Open dashboard
          </Link>
        </section>
      </main>
    </div>
  );
}
