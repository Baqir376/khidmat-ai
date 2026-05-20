"use client";
import { AgentTracePanel } from "@/components/dashboard/AgentTracePanel";
import { InteractiveDesk } from "@/components/dashboard/InteractiveDesk";
import { BookingTable } from "@/components/dashboard/BookingTable";
import { ProviderMap } from "@/components/dashboard/ProviderMap";

export default function DashboardOverview() {
  return (
    <div className="space-y-6">
      <header className="mb-8">
        <h1 className="text-3xl font-bold text-white">System Overview</h1>
        <p className="text-slate-400">Live orchestrator telemetry and metrics.</p>
      </header>

      <InteractiveDesk />

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 bg-slate-900 border border-slate-800 rounded-xl p-6">
          <h2 className="text-xl font-bold text-white mb-4">Recent Bookings</h2>
          <BookingTable />
        </div>
        
        <div className="space-y-6">
          <AgentTracePanel isRunning={true} />
          
          <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
            <h3 className="text-white font-semibold mb-3">Live Provider Map</h3>
            <ProviderMap />
          </div>
        </div>
      </div>
    </div>
  );
}
