"use client";
import { useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";

import { API_BASE } from "@/utils/api";

interface Trace {
  agent: string;
  action: string;
  timestamp: string;
}

const MOCK_TRACES: Trace[] = [
  { agent: "Intent", action: "Analyzing natural language booking request...", timestamp: "" },
  { agent: "Discovery", action: "Querying spatial database for Plumbers in Karachi...", timestamp: "" },
  { agent: "Matching", action: "Scoring 15 candidates based on reputation and distance...", timestamp: "" },
  { agent: "Negotiation", action: "Calculating optimal rate (Avg: 800 PKR)...", timestamp: "" },
  { agent: "Booking", action: "Confirming booking and dispatching provider...", timestamp: "" },
  { agent: "FollowUp", action: "Scheduling reminders and satisfaction survey...", timestamp: "" },
];

export function AgentTracePanel({ isRunning = true }: { isRunning?: boolean }) {
  const [traces, setTraces] = useState<Trace[]>([]);
  const [loading, setLoading] = useState(true);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!isRunning) return;

    const fetchTraces = () => {
      fetch(`${API_BASE}/api/admin/recent-traces?limit=15`)
        .then(res => res.json())
        .then(data => {
          if (data && data.traces && data.traces.length > 0) {
            // Sort by timestamp ascending
            const sorted = [...data.traces].sort(
              (a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()
            );
            setTraces(sorted);
          } else {
            // Simulated fallbacks
            const now = new Date();
            const mocks = MOCK_TRACES.map((t, idx) => ({
              ...t,
              timestamp: new Date(now.getTime() - (MOCK_TRACES.length - idx) * 3000).toISOString()
            }));
            setTraces(mocks);
          }
          setLoading(false);
        })
        .catch(err => {
          console.error("Error fetching live agent traces:", err);
          const now = new Date();
          const mocks = MOCK_TRACES.map((t, idx) => ({
            ...t,
            timestamp: new Date(now.getTime() - (MOCK_TRACES.length - idx) * 3000).toISOString()
          }));
          setTraces(mocks);
          setLoading(false);
        });
    };

    fetchTraces();
    const interval = setInterval(fetchTraces, 3000);

    return () => clearInterval(interval);
  }, [isRunning]);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [traces]);

  return (
    <div className="bg-slate-900 border border-slate-800 rounded-xl p-4 overflow-hidden h-[300px] flex flex-col font-mono text-sm">
      <div className="flex items-center gap-2 mb-4 pb-2 border-b border-slate-800">
        <div className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
        <h3 className="text-slate-300 font-semibold tracking-wider">LIVE AGENT TRACES</h3>
      </div>
      <div ref={scrollRef} className="flex-1 overflow-y-auto space-y-3 pr-2 scroll-smooth">
        <AnimatePresence>
          {traces.map((trace, idx) => (
            <motion.div
              key={`trace-${idx}`}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              className="flex gap-3"
            >
              <span className="text-slate-500 shrink-0">
                [{new Date(trace.timestamp).toLocaleTimeString()}]
              </span>
              <span className="text-indigo-400 shrink-0 font-bold">
                {trace.agent}:
              </span>
              <span className="text-emerald-400">
                {trace.action}
              </span>
            </motion.div>
          ))}
          {loading && (
            <motion.div
              key="processing"
              initial={{ opacity: 0 }}
              animate={{ opacity: [0.3, 1, 0.3] }}
              transition={{ repeat: Infinity, duration: 1.5 }}
              className="text-slate-500"
            >
              _ Processing...
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
