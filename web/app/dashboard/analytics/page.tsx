"use client";
import { useEffect, useState } from "react";
import { TrendingUp, Users, Wrench, CreditCard, Award } from "lucide-react";

import { API_BASE } from "@/utils/api";

interface ProviderAnalytics {
  id: string;
  name: string;
  serviceType: string;
  jobsCompleted: number;
  totalIncome: number;
  rating: number;
}

export default function AnalyticsPage() {
  const [stats, setStats] = useState({
    totalBookings: 0,
    activeProviders: 0,
    totalRevenue: 0,
    completionRate: 0
  });
  const [providerStats, setProviderStats] = useState<ProviderAnalytics[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchAnalytics = async () => {
      try {
        const [bookingsRes, providersRes] = await Promise.all([
          fetch(`${API_BASE}/api/bookings`),
          fetch(`${API_BASE}/api/providers/search?limit=100`)
        ]);
        const bookingsData = await bookingsRes.json();
        const providersData = await providersRes.json();
        
        const bookings = bookingsData.bookings || [];
        const providers = providersData.providers || [];
        const confirmedBookings = bookings.filter(
          (b: any) => b.status === "confirmed" || b.status === "completed"
        );
        const totalRev = confirmedBookings.reduce(
          (sum: number, b: any) => sum + (b.final_price || b.quoted_price || b.price || 0),
          0
        );
        
        setStats({
          totalBookings: bookings.length,
          activeProviders: providers.length || 0,
          totalRevenue: totalRev,
          completionRate: bookings.length ? Math.round((confirmedBookings.length / bookings.length) * 100) : 100
        });

        // Calculate analytics per provider with precise completed statuses (matching backend)
        const computedProviders: ProviderAnalytics[] = providers.map((p: any) => {
          const providerBookings = bookings.filter((b: any) => b.provider_id === p.id);
          const completedBookings = providerBookings.filter((b: any) => b.status === "completed");
          
          // Use the dynamic completed jobs from profile registry
          const totalJobs = p.jobs_completed || 0;
          
          // Sum the provider's completed bookings price, or fallback using rate * jobs completed
          let income = completedBookings.reduce(
            (sum: number, b: any) => sum + (b.final_price || b.quoted_price || b.price || 0),
            0
          );
          if (income === 0 && totalJobs > 0) {
            const baseRate = p.rate || p.hourly_rate || p.fixed_rate || 800;
            income = totalJobs * baseRate;
          }

          return {
            id: p.id,
            name: p.name_en || p.name || "Provider",
            serviceType: p.service_type_id || "General",
            jobsCompleted: totalJobs,
            totalIncome: income,
            rating: p.rating || 5.0
          };
        });

        // Sort by total income descending
        computedProviders.sort((a, b) => b.totalIncome - a.totalIncome);
        setProviderStats(computedProviders);
        setLoading(false);
      } catch (err) {
        console.error("Failed to fetch analytics:", err);
        setLoading(false);
      }
    };

    fetchAnalytics();
    const interval = setInterval(fetchAnalytics, 15000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="space-y-6">
      <header className="mb-8">
        <h1 className="text-3xl font-bold text-white">Platform Analytics</h1>
        <p className="text-slate-400">High-level metrics and marketplace performance.</p>
      </header>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-blue-500/20 text-blue-400 rounded-lg">
              <TrendingUp className="w-6 h-6" />
            </div>
            <div>
              <p className="text-slate-400 text-sm">Total Bookings</p>
              <h3 className="text-2xl font-bold text-white">{stats.totalBookings}</h3>
            </div>
          </div>
        </div>

        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-emerald-500/20 text-emerald-400 rounded-lg">
              <Users className="w-6 h-6" />
            </div>
            <div>
              <p className="text-slate-400 text-sm">Active Providers</p>
              <h3 className="text-2xl font-bold text-white">{stats.activeProviders}</h3>
            </div>
          </div>
        </div>

        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-purple-500/20 text-purple-400 rounded-lg">
              <CreditCard className="w-6 h-6" />
            </div>
            <div>
              <p className="text-slate-400 text-sm">GMV (Total Income)</p>
              <h3 className="text-2xl font-bold text-white">PKR {stats.totalRevenue.toLocaleString()}</h3>
            </div>
          </div>
        </div>

        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-orange-500/20 text-orange-400 rounded-lg">
              <Wrench className="w-6 h-6" />
            </div>
            <div>
              <p className="text-slate-400 text-sm">Conversion Rate</p>
              <h3 className="text-2xl font-bold text-white">{stats.completionRate}%</h3>
            </div>
          </div>
        </div>
      </div>

      {/* Providers Performance Breakdown */}
      <div className="bg-slate-900 border border-slate-800 rounded-xl p-6 mt-8">
        <h2 className="text-xl font-bold text-white mb-6 flex items-center gap-2">
          <Award className="w-5 h-5 text-indigo-400" />
          <span>Provider Earnings & Performance Leaderboard</span>
        </h2>
        
        {loading ? (
          <div className="py-20 text-center text-slate-500 animate-pulse">Loading performance stats...</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm text-slate-400">
              <thead className="text-xs uppercase bg-slate-800/50 text-slate-300">
                <tr>
                  <th className="px-6 py-3 rounded-tl-lg">Rank & Provider</th>
                  <th className="px-6 py-3">Service Specialty</th>
                  <th className="px-6 py-3">Rating</th>
                  <th className="px-6 py-3">Jobs Completed</th>
                  <th className="px-6 py-3 rounded-tr-lg">Total Income (PKR)</th>
                </tr>
              </thead>
              <tbody>
                {providerStats.map((p, idx) => (
                  <tr key={p.id} className="border-b border-slate-800 hover:bg-slate-800/20 transition-colors">
                    <td className="px-6 py-4 flex items-center gap-3">
                      <span className={`w-6 h-6 rounded-full flex items-center justify-center font-bold text-xs ${
                        idx === 0 ? 'bg-amber-500/20 text-amber-400' :
                        idx === 1 ? 'bg-slate-400/20 text-slate-300' :
                        idx === 2 ? 'bg-amber-700/20 text-amber-600' :
                        'bg-slate-800 text-slate-500'
                      }`}>
                        {idx + 1}
                      </span>
                      <span className="font-semibold text-white">{p.name}</span>
                    </td>
                    <td className="px-6 py-4">
                      <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                        {p.serviceType}
                      </span>
                    </td>
                    <td className="px-6 py-4 font-semibold text-amber-400">★ {p.rating.toFixed(1)}</td>
                    <td className="px-6 py-4 font-mono font-bold text-slate-300">{p.jobsCompleted}</td>
                    <td className="px-6 py-4 font-mono font-bold text-white text-base">
                      PKR {p.totalIncome.toLocaleString()}
                    </td>
                  </tr>
                ))}
                {providerStats.length === 0 && (
                  <tr>
                    <td colSpan={5} className="px-6 py-8 text-center text-slate-500">
                      No active provider data available.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
