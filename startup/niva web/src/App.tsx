import { useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate, Outlet, useLocation } from 'react-router-dom';

import ClinicalInsightsUpdated from './pages/ClinicalInsightsUpdated';
import ClinicalInsights3D from './pages/ClinicalInsights3D';
import TrendAnalytics from './pages/TrendAnalytics';
import DeviceSettings from './pages/DeviceSettings';
import ClinicianPDFDark from './pages/ClinicianPDFDark';
import ClinicianPDF from './pages/ClinicianPDF';
import MainDashboard from './pages/MainDashboard';
import SymmetryDetailedReport from './pages/SymmetryDetailedReport';
import ClinicalInsightsHeatmapLegend from './pages/ClinicalInsightsHeatmapLegend';
import ClinicalInsights3DHeatmap from './pages/ClinicalInsights3DHeatmap';
import ClinicalInsightsAnatomyLegend from './pages/ClinicalInsightsAnatomyLegend';
import ClinicalInsights from './pages/ClinicalInsights';

import BottomNav from './components/BottomNav';

function Layout() {
  const { pathname } = useLocation();

  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);

  return (
    <div className="w-full relative mx-auto bg-white dark:bg-slate-900 min-h-screen pb-24 max-w-md shadow-2xl overflow-hidden shadow-slate-200 dark:shadow-slate-900">
      <Outlet />
      {/* Bottom Nav provided globally via layout */}
      <BottomNav />
    </div>
  );
}

function CenteredApp() {
  return (
    <div className="min-h-screen bg-slate-50 dark:bg-black flex justify-center w-full">
      <Layout />
    </div>
  )
}

function App() {
  const routerBase = import.meta.env.BASE_URL.replace(/\/$/, '') || '/';

  return (
    <BrowserRouter basename={routerBase}>
      <Routes>
        {/* Route element centers the 'mobile app' aspect ratio horizontally on larger screens */}
        <Route element={<CenteredApp />}>
          <Route path="/" element={<Navigate to="/main" replace />} />
          
          {/* Primary Nav Hub Routes */}
          <Route path="/main" element={<MainDashboard />} />
          <Route path="/insights" element={<ClinicalInsightsUpdated />} />
          <Route path="/trends" element={<TrendAnalytics />} />
          <Route path="/settings" element={<DeviceSettings />} />
          
          {/* Deep Links / Drill Downs */}
          <Route path="/insights/3d" element={<ClinicalInsights3D />} />
          <Route path="/insights/heatmap" element={<ClinicalInsightsHeatmapLegend />} />
          <Route path="/insights/3d-heatmap" element={<ClinicalInsights3DHeatmap />} />
          <Route path="/insights/anatomy" element={<ClinicalInsightsAnatomyLegend />} />
          <Route path="/insights/simple" element={<ClinicalInsights />} />
          
          <Route path="/symmetry" element={<SymmetryDetailedReport />} />
          
          <Route path="/pdf" element={<ClinicianPDF />} />
          <Route path="/pdf-dark" element={<ClinicianPDFDark />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
