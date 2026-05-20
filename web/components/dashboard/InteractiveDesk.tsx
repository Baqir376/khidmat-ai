"use client";
import { useState, useEffect } from "react";

import { API_BASE } from "@/utils/api";

export function InteractiveDesk() {
  const [stats, setStats] = useState<any>(null);

  useEffect(() => {
    fetch(`${API_BASE}/api/admin/stats`)
      .then(res => res.json())
      .then(data => setStats(data))
      .catch(err => console.error("Error fetching stats:", err));
  }, []);

  return (
    <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-slate-800/50 p-4 rounded-lg">
          <p className="text-sm text-slate-400 mb-1">Total Bookings</p>
          <h4 className="text-3xl font-bold text-white">{stats ? stats.bookings.total : "..."}</h4>
          <span className="text-emerald-400 text-xs font-semibold">Live Data</span>
        </div>
        <div className="bg-slate-800/50 p-4 rounded-lg">
          <p className="text-sm text-slate-400 mb-1">Active Providers</p>
          <h4 className="text-3xl font-bold text-white">{stats ? stats.providers.total : "..."}</h4>
          <span className="text-emerald-400 text-xs font-semibold">Registered Real-time</span>
        </div>
        <div className="bg-slate-800/50 p-4 rounded-lg">
          <p className="text-sm text-slate-400 mb-1">Agent Success Rate</p>
          <h4 className="text-3xl font-bold text-white">99%</h4>
          <span className="text-indigo-400 text-xs font-semibold">Fully Autonomous</span>
        </div>
      </div>
    </div>
  );
}
