"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { AdminChatbot } from "@/components/dashboard/AdminChatbot";
import { LogOut, ShieldAlert, Wrench } from "lucide-react";


export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const [authorized, setAuthorized] = useState(false);

  useEffect(() => {
    const isLoggedIn = localStorage.getItem("admin_logged_in") === "true";
    if (!isLoggedIn) {
      router.push("/");
    } else {
      setAuthorized(true);
    }
  }, [router]);

  const handleLogout = () => {
    localStorage.removeItem("admin_logged_in");
    router.push("/");
  };

  if (!authorized) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center font-mono">
        <div className="flex flex-col items-center gap-3 text-slate-500">
          <ShieldAlert className="w-8 h-8 text-emerald-500 animate-bounce" />
          <span>Verifying secure administrative session...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-950 flex">
      {/* Sidebar */}
      <aside className="w-64 bg-slate-900 border-r border-slate-800 hidden md:flex flex-col">
        <div className="p-6 border-b border-slate-800">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center shadow-md shadow-emerald-500/10 shrink-0">
              <Wrench className="w-4 h-4 text-emerald-400" />
            </div>
            <span className="text-white font-extrabold tracking-wider font-mono text-sm uppercase bg-clip-text bg-gradient-to-r from-emerald-400 to-teal-200">
              KaamSaaz Admin
            </span>
          </div>
        </div>
        <nav className="flex-1 p-4 space-y-2">
          {[
            { name: "Overview", path: "/dashboard" },
            { name: "Bookings", path: "/dashboard/bookings" },
            { name: "Providers", path: "/dashboard/providers" },
            { name: "Analytics", path: "/dashboard/analytics" },
          ].map(item => (
            <button 
              key={item.name}
              onClick={() => router.push(item.path)}
              className="w-full text-left block px-4 py-2 text-slate-400 hover:bg-slate-800 hover:text-white rounded-lg transition-colors font-medium font-mono text-sm"
            >
              {item.name}
            </button>
          ))}
        </nav>

        {/* Admin Log Out */}
        <div className="p-4 border-t border-slate-800 space-y-3">
          <button
            onClick={handleLogout}
            className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 font-semibold rounded-lg transition-colors text-sm border border-rose-500/20 font-mono uppercase text-xs tracking-wider"
          >
            <LogOut className="w-4 h-4" />
            <span>Sign Out</span>
          </button>
          <div className="text-center text-[10px] text-slate-500 uppercase tracking-widest font-mono">
            System Telemetry Active
          </div>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 overflow-y-auto">
        <div className="p-8">
          {children}
        </div>
      </main>

      {/* Copilot */}
      <AdminChatbot />
    </div>
  );
}
