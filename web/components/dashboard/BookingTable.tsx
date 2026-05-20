"use client";
import React, { useState, useEffect } from "react";
import { ChatViewer } from "./ChatViewer";
import { motion, AnimatePresence } from "framer-motion";

import { API_BASE } from "@/utils/api";

export function BookingTable() {
  const [bookings, setBookings] = useState<any[]>([]);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  useEffect(() => {
    fetch(`${API_BASE}/api/bookings`)
      .then(res => res.json())
      .then(data => {
        if (data.bookings) {
          setBookings(data.bookings);
        }
      })
      .catch(err => console.error("Error fetching bookings:", err));
  }, []);

  return (
    <div className="overflow-x-auto w-full">
      <table className="w-full text-left text-sm text-slate-400">
        <thead className="text-xs uppercase bg-slate-800/50 text-slate-300">
          <tr>
            <th className="px-6 py-3 rounded-tl-lg">ID</th>
            <th className="px-6 py-3">Customer</th>
            <th className="px-6 py-3">Provider</th>
            <th className="px-6 py-3">Service</th>
            <th className="px-6 py-3">Status</th>
            <th className="px-6 py-3">Amount</th>
            <th className="px-6 py-3 rounded-tr-lg">Date</th>
          </tr>
        </thead>
        <tbody>
          {bookings.map((b, i) => (
            <React.Fragment key={b.id || i}>
              <tr 
                onClick={() => setExpandedId(expandedId === b.id ? null : b.id)}
                className="border-b border-slate-800 hover:bg-slate-800/20 transition-colors cursor-pointer"
              >
                <td className="px-6 py-4 font-medium text-white">{b.id?.substring(0,8)}</td>
                <td className="px-6 py-4">{b.user_name || b.citizen_id || "Customer"}</td>
                <td className="px-6 py-4 text-amber-400">{b.provider_name || b.provider_id || "Unassigned"}</td>
                <td className="px-6 py-4 text-emerald-400">{b.service_type_id}</td>
                <td className="px-6 py-4">
                  <span className={`px-2 py-1 rounded-full text-xs font-semibold uppercase ${
                    b.status === 'completed' ? 'bg-emerald-500/20 text-emerald-400' : 
                    b.status === 'accepted' ? 'bg-amber-500/20 text-amber-400' : 
                    'bg-indigo-500/20 text-indigo-400'
                  }`}>
                    {b.status || 'pending'}
                  </span>
                </td>
                <td className="px-6 py-4">{b.quoted_price} PKR</td>
                <td className="px-6 py-4">{b.scheduled_date || "Today"} {b.scheduled_time}</td>
              </tr>
              <AnimatePresence>
                {expandedId === b.id && (
                  <tr>
                    <td colSpan={7} className="p-0 border-b border-slate-800">
                      <motion.div 
                        initial={{ height: 0, opacity: 0 }}
                        animate={{ height: 'auto', opacity: 1 }}
                        exit={{ height: 0, opacity: 0 }}
                        className="overflow-hidden bg-slate-800/30"
                      >
                        <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-6">
                          <div>
                            <h4 className="text-white font-semibold mb-4">Booking Details</h4>
                            <div className="space-y-2 text-sm">
                              <p><span className="text-slate-500">Full ID:</span> {b.id}</p>
                              <p><span className="text-slate-500">Customer Name:</span> {b.user_name || "Customer"}</p>
                              <p><span className="text-slate-500">Provider Name:</span> {b.provider_name || "Unassigned"}</p>
                              <p><span className="text-slate-500">Address:</span> {b.location_address || b.service_address || "N/A"}</p>
                              <p><span className="text-slate-500">Coordinates:</span> {b.latitude || b.service_lat}, {b.longitude || b.service_lng}</p>
                              <p><span className="text-slate-500">Description:</span> {b.problem_description || b.original_input}</p>
                              <p><span className="text-slate-500">Created:</span> {b.created_at ? new Date(b.created_at).toLocaleString() : "N/A"}</p>
                            </div>
                          </div>
                          <div>
                            <h4 className="text-white font-semibold mb-4">Live Chat Monitor</h4>
                            <ChatViewer bookingId={b.id} />
                          </div>
                        </div>
                      </motion.div>
                    </td>
                  </tr>
                )}
              </AnimatePresence>
            </React.Fragment>
          ))}
          {bookings.length === 0 && (
            <tr>
              <td colSpan={7} className="px-6 py-8 text-center text-slate-500">
                No active bookings found
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
