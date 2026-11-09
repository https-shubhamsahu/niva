import { useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate, Outlet, useLocation } from 'react-router-dom';

import DeviceSettings from './pages/DeviceSettings';
import MainDashboard from './pages/MainDashboard';
import NoDeviceData from './pages/NoDeviceData';

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
          <Route path="/insights" element={<NoDeviceData title="Details" />} />
          <Route path="/trends" element={<NoDeviceData title="Trends" />} />
          <Route path="/settings" element={<DeviceSettings />} />
          
          {/* Deep links kept so old URLs still resolve. These pages only ever showed
              invented values, so each now shows an honest empty state. */}
          <Route path="/insights/3d" element={<NoDeviceData title="Details" />} />
          <Route path="/insights/heatmap" element={<NoDeviceData title="Details" />} />
          <Route path="/insights/3d-heatmap" element={<NoDeviceData title="Details" />} />
          <Route path="/insights/anatomy" element={<NoDeviceData title="Details" />} />
          <Route path="/insights/simple" element={<NoDeviceData title="Details" />} />
          
          <Route path="/symmetry" element={<NoDeviceData title="Symmetry" />} />
          
          <Route path="/pdf" element={<NoDeviceData title="Report" />} />
          <Route path="/pdf-dark" element={<NoDeviceData title="Report" />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
