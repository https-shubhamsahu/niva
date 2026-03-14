import React from 'react';
import { Link, useLocation } from 'react-router-dom';

export default function BottomNav() {
  const location = useLocation();
  const path = location.pathname;

  // We should not show BottomNav on PDF views or Detailed Symmetry
  if (path.startsWith('/pdf') || path === '/symmetry') {
     return null;
  }

  const navItems = [
    { label: 'Dashboard', path: '/main', icon: 'grid_view' },
    { label: 'Trends', path: '/trends', icon: 'trending_up' },
    { label: 'Health', path: '/insights', icon: 'favorite' },
    { label: 'Settings', path: '/settings', icon: 'settings' },
  ];

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-white/90 dark:bg-slate-900/90 backdrop-blur-lg border-t border-slate-200 dark:border-slate-800 pb-8 pt-2 px-6 z-[100]">
      <div className="flex justify-between items-center max-w-md mx-auto">
        {navItems.map(item => {
          // Highlight active paths (e.g., /insights/3d should highlight Health)
          const isActive = path === item.path || (path.startsWith('/insights') && item.path === '/insights');
          return (
            <Link 
              key={item.label}
              to={item.path} 
              className={`flex flex-col items-center gap-1 ${isActive ? 'text-primary' : 'text-slate-400'}`}
            >
              <span className={`material-symbols-outlined ${isActive ? 'fill-1' : ''}`}>
                {item.icon}
              </span>
              <span className="text-[10px] font-semibold">{item.label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
