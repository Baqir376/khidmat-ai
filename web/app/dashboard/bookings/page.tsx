"use client";
import { useEffect, useState, useRef } from "react";
import { 
  Wrench, MapPin, Clock, CheckCircle, ShieldAlert, ShieldCheck, 
  User, Phone, Calendar, DollarSign, MessageSquare, Send, 
  Sparkles, RefreshCw, AlertTriangle, Shield, CheckSquare, XCircle
} from "lucide-react";

import { API_BASE } from "@/utils/api";

function getAudioDataUri(base64: string): string {
  if (!base64) return "";
  const clean = base64.replace(/\s/g, "");
  
  if (clean.startsWith("UklG")) {
    return `data:audio/wav;base64,${clean}`;
  }
  if (clean.startsWith("SUQz") || clean.startsWith("//tQx") || clean.startsWith("/+MY")) {
    return `data:audio/mpeg;base64,${clean}`;
  }
  // Default to standard highly supported MP4 audio container for AAC (M4A)
  return `data:audio/mp4;base64,${clean}`;
}

export default function BookingsPage() {
  const [bookings, setBookings] = useState<any[]>([]);
  const [selectedBooking, setSelectedBooking] = useState<any | null>(null);
  const [selectedProvider, setSelectedProvider] = useState<any | null>(null);
  const [chatMessages, setChatMessages] = useState<any[]>([]);
  const [adminMessage, setAdminMessage] = useState("");
  const [loading, setLoading] = useState(true);
  const [chatLoading, setChatLoading] = useState(false);
  const [sendingMessage, setSendingMessage] = useState(false);

  const chatEndRef = useRef<HTMLDivElement>(null);

  // Poll list of bookings
  useEffect(() => {
    const fetchBookings = async () => {
      try {
        const res = await fetch(`${API_BASE}/api/bookings`);
        const data = await res.json();
        const newBookings = data.bookings || [];
        
        setBookings((prev: any[]) => {
          if (prev.length === newBookings.length) {
            const isMatch = prev.every((b, idx) => 
              b.id === newBookings[idx].id && 
              b.status === newBookings[idx].status && 
              b.quoted_price === newBookings[idx].quoted_price
            );
            if (isMatch) return prev; // Bypass unnecessary re-render
          }
          return newBookings;
        });
        
        // Update selected booking's live details if open
        if (selectedBooking) {
          const current = newBookings.find((b: any) => b.id === selectedBooking.id);
          if (current) {
            setSelectedBooking((prev: any) => {
              if (
                prev &&
                prev.status === current.status && 
                prev.quoted_price === current.quoted_price &&
                prev.escrow_active === current.escrow_active &&
                prev.blockchain_tx_hash === current.blockchain_tx_hash
              ) {
                return prev;
              }
              return current;
            });
          }
        }
      } catch (err) {
        console.error("Failed to fetch bookings:", err);
      } finally {
        setLoading(false);
      }
    };
    fetchBookings();
    const interval = setInterval(fetchBookings, 20000);
    return () => clearInterval(interval);
  }, [selectedBooking]);

  // Fetch provider info when a booking is selected
  useEffect(() => {
    if (!selectedBooking || !selectedBooking.provider_id) {
      setSelectedProvider(null);
      return;
    }
    const fetchProvider = async () => {
      try {
        const res = await fetch(`${API_BASE}/api/providers/${selectedBooking.provider_id}`);
        if (res.ok) {
          const data = await res.json();
          setSelectedProvider((prev: any) => {
            if (prev && prev.id === data.id && prev.rating === data.rating && prev.cnic_verified === data.cnic_verified) {
              return prev;
            }
            return data;
          });
        } else {
          setSelectedProvider(null);
        }
      } catch (err) {
        console.error("Failed to fetch provider details:", err);
        setSelectedProvider(null);
      }
    };
    fetchProvider();
  }, [selectedBooking?.provider_id]);

  // Poll chat messages for the selected booking
  useEffect(() => {
    if (!selectedBooking) {
      setChatMessages([]);
      return;
    }

    const fetchChat = async () => {
      try {
        const res = await fetch(`${API_BASE}/api/chat/${selectedBooking.id}`);
        if (res.ok) {
          const data = await res.json();
          const newMessages = data.messages || [];
          
          setChatMessages((prev: any[]) => {
            if (prev.length === newMessages.length) {
              const isMatch = prev.every((msg, idx) => 
                msg.text === newMessages[idx].text && 
                msg.timestamp === newMessages[idx].timestamp &&
                msg.sender_id === newMessages[idx].sender_id
              );
              if (isMatch) return prev; // Avoid unnecessary DOM updates
            }
            return newMessages;
          });
        }
      } catch (err) {
        console.error("Failed to fetch chat messages:", err);
      }
    };
    
    fetchChat();
    const chatInterval = setInterval(fetchChat, 10000);
    return () => clearInterval(chatInterval);
  }, [selectedBooking?.id]);

  // Auto-scroll chat to bottom
  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [chatMessages]);

  // Send admin message to the chat
  const handleSendAdminMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedBooking || !adminMessage.trim()) return;

    setSendingMessage(true);
    try {
      const res = await fetch(`${API_BASE}/api/chat/`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          booking_id: selectedBooking.id,
          sender_id: "admin",
          text: adminMessage.trim(),
        }),
      });

      if (res.ok) {
        const data = await res.json();
        // Append newly created moderated message immediately for fast feedback
        const newMsg = {
          booking_id: selectedBooking.id,
          sender_id: "admin",
          text: data.text || adminMessage.trim(),
          timestamp: new Date().toISOString(),
        };
        setChatMessages(prev => [...prev, newMsg]);
        setAdminMessage("");
      }
    } catch (err) {
      console.error("Failed to send admin broadcast message:", err);
    } finally {
      setSendingMessage(false);
    }
  };

  // Human-readable Date/Time parser (removes raw JSON/maps)
  function formatScheduledDateTime(dateVal: any, timeVal: any) {
    if (!dateVal) return "ASAP";
    
    let dateStr = "";
    if (typeof dateVal === "object" && dateVal !== null) {
      if (dateVal.resolved_date) dateStr = dateVal.resolved_date;
      else if (dateVal.date) dateStr = dateVal.date;
      else if (dateVal.day && dateVal.month && dateVal.year) {
        dateStr = `${dateVal.year}-${String(dateVal.month).padStart(2, '0')}-${String(dateVal.day).padStart(2, '0')}`;
      } else {
        dateStr = JSON.stringify(dateVal);
      }
    } else {
      dateStr = String(dateVal);
    }

    if (!dateStr || dateStr.toLowerCase() === "asap") return "ASAP";

    if (dateStr.startsWith("{")) {
      try {
        const parsed = JSON.parse(dateStr);
        if (parsed.resolved_date) dateStr = parsed.resolved_date;
        else if (parsed.date) dateStr = parsed.date;
        else if (parsed.day && parsed.month && parsed.year) {
          dateStr = `${parsed.year}-${String(parsed.month).padStart(2, '0')}-${String(parsed.day).padStart(2, '0')}`;
        }
      } catch (_) {}
    }

    let formattedDate = dateStr;
    try {
      const parts = dateStr.split("-");
      if (parts.length === 3) {
        const year = parseInt(parts[0]);
        const month = parseInt(parts[1]);
        const day = parseInt(parts[2]);
        const date = new Date(year, month - 1, day);
        formattedDate = date.toLocaleDateString("en-US", {
          weekday: "long",
          year: "numeric",
          month: "long",
          day: "numeric"
        });
      }
    } catch (_) {}

    if (!timeVal) return formattedDate;

    let timeStr = "";
    if (typeof timeVal === "object" && timeVal !== null) {
      if (timeVal.resolved_time) timeStr = timeVal.resolved_time;
      else if (timeVal.time) timeStr = timeVal.time;
      else if (timeVal.hour) {
        const hr = timeVal.hour;
        const min = timeVal.minute || 0;
        const period = timeVal.period || "";
        timeStr = `${hr}:${String(min).padStart(2, '0')} ${period}`;
      } else {
        timeStr = JSON.stringify(timeVal);
      }
    } else {
      timeStr = String(timeVal);
    }

    if (timeStr.startsWith("{")) {
      try {
        const parsed = JSON.parse(timeStr);
        if (parsed.resolved_time) timeStr = parsed.resolved_time;
        else if (parsed.time) timeStr = parsed.time;
        else if (parsed.hour) {
          const hr = parsed.hour;
          const min = parsed.minute || 0;
          const period = parsed.period || "";
          timeStr = `${hr}:${String(min).padStart(2, '0')} ${period}`;
        }
      } catch (_) {}
    }

    let formattedTime = timeStr.trim();
    try {
      const cleanTime = formattedTime.toLowerCase();
      if (cleanTime.includes("am") || cleanTime.includes("pm")) {
        const isPm = cleanTime.includes("pm");
        const digits = cleanTime.replace(/[^0-9:]/g, "");
        const parts = digits.split(":");
        if (parts.length > 0) {
          let hour = parseInt(parts[0]);
          let minute = parts.length > 1 ? parseInt(parts[1]) : 0;
          if (hour === 0) hour = 12;
          if (hour > 12) hour = hour % 12;
          const period = isPm ? "PM" : "AM";
          formattedTime = `${hour}:${String(minute).padStart(2, '0')} ${period}`;
        }
      } else {
        const parts = formattedTime.split(":");
        if (parts.length > 0) {
          let hour = parseInt(parts[0]);
          let minute = parts.length > 1 ? parseInt(parts[1].replace(/[^0-9]/g, "")) : 0;
          const ampm = hour >= 12 ? "PM" : "AM";
          const hour12 = hour % 12 === 0 ? 12 : hour % 12;
          formattedTime = `${hour12}:${String(minute).padStart(2, '0')} ${ampm}`;
        }
      }
    } catch (_) {}

    return `${formattedDate} at ${formattedTime}`;
  }

  return (
    <div className="space-y-6">
      <header className="mb-4">
        <h1 className="text-3xl font-bold text-white tracking-tight flex items-center gap-3">
          <Sparkles className="w-8 h-8 text-emerald-400 animate-pulse" />
          Live Booking & Chat Monitor
        </h1>
        <p className="text-slate-400">Bidirectional live pipeline tracking, security verification, and moderated chat supervisor.</p>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* LEFT COLUMN: All Bookings List */}
        <div className="lg:col-span-5 bg-slate-900 border border-slate-800 rounded-xl overflow-hidden flex flex-col h-[78vh]">
          <div className="p-4 border-b border-slate-800 flex justify-between items-center bg-slate-900/60 backdrop-blur">
            <h2 className="text-lg font-bold text-white flex items-center gap-2">
              Recent Activity
              <span className="text-xs px-2 py-0.5 bg-emerald-500/20 text-emerald-400 font-semibold rounded-full">
                {bookings.length}
              </span>
            </h2>
            <div className="flex gap-2">
              <span className="text-xs bg-slate-800 border border-slate-700 px-2 py-1 rounded text-slate-400 font-mono flex items-center gap-1.5">
                <RefreshCw className="w-3 h-3 animate-spin text-emerald-400" />
                Live
              </span>
            </div>
          </div>

          <div className="overflow-y-auto flex-1 divide-y divide-slate-800">
            {loading ? (
              <div className="p-8 text-center text-slate-500 font-medium">Loading bookings...</div>
            ) : bookings.length === 0 ? (
              <div className="p-8 text-center text-slate-500 font-medium">No bookings found in system.</div>
            ) : (
              bookings.map((b) => (
                <div 
                  key={b.id}
                  onClick={() => setSelectedBooking(b)}
                  className={`p-4 cursor-pointer transition-all hover:bg-slate-800/40 relative ${
                    selectedBooking?.id === b.id ? "bg-emerald-500/10 border-l-4 border-emerald-500" : ""
                  }`}
                >
                  <div className="flex justify-between items-start gap-2 mb-2">
                    <div className="font-semibold text-white capitalize text-sm flex items-center gap-1.5">
                      <Wrench className="w-4 h-4 text-emerald-400" />
                      {b.service_type_id?.replace("_", " ") || "General Service"}
                    </div>
                    <span className={`text-[10px] px-2 py-0.5 rounded-full font-bold uppercase ${
                      b.status === "completed" ? "bg-emerald-500/20 text-emerald-400" :
                      b.status === "confirmed" ? "bg-amber-500/20 text-amber-400" :
                      b.status === "cancelled" ? "bg-red-500/20 text-red-400" :
                      "bg-indigo-500/20 text-indigo-400"
                    }`}>
                      {b.status}
                    </span>
                  </div>

                  <div className="text-xs text-slate-400 flex justify-between items-center">
                    <span className="truncate max-w-[150px]">Customer: {b.user_name || "Citizen"}</span>
                    <span className="font-semibold text-emerald-300">PKR {b.quoted_price}</span>
                  </div>

                  <div className="text-[11px] text-slate-500 mt-2 flex items-center gap-1.5">
                    <Clock className="w-3.5 h-3.5 text-slate-600" />
                    <span className="truncate">{formatScheduledDateTime(b.scheduled_date, b.scheduled_time)}</span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* RIGHT COLUMN: Master Details & Live Chat Drawer */}
        <div className="lg:col-span-7 bg-slate-900 border border-slate-800 rounded-xl overflow-hidden flex flex-col h-[78vh]">
          {selectedBooking ? (
            <div className="flex flex-col h-full">
              {/* Drawer Header */}
              <div className="p-4 border-b border-slate-800 bg-slate-950/40 flex justify-between items-center">
                <div>
                  <div className="text-xs text-slate-500 font-mono">BOOKING ID: {selectedBooking.id}</div>
                  <h3 className="text-lg font-bold text-white capitalize flex items-center gap-2">
                    {selectedBooking.service_type_id?.replace("_", " ")}
                    <span className={`text-xs px-2 py-0.5 rounded-full font-bold uppercase ${
                      selectedBooking.status === "completed" ? "bg-emerald-500/20 text-emerald-400" :
                      selectedBooking.status === "confirmed" ? "bg-amber-500/20 text-amber-400" :
                      selectedBooking.status === "cancelled" ? "bg-red-500/20 text-red-400" :
                      "bg-indigo-500/20 text-indigo-400"
                    }`}>
                      {selectedBooking.status}
                    </span>
                  </h3>
                </div>
                <div className="text-right">
                  <div className="text-xs text-slate-500">Escrow Value</div>
                  <div className="text-xl font-bold text-emerald-400">PKR {selectedBooking.quoted_price}</div>
                </div>
              </div>

              {/* Drawer Body Container (Scrollable tabs & Info Cards) */}
              <div className="flex-1 overflow-y-auto p-6 space-y-6">
                {/* 1. Split Customer & Provider Profile Cards */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {/* Customer Card */}
                  <div className="bg-slate-950/50 border border-slate-800/80 rounded-xl p-4">
                    <h4 className="text-xs font-bold uppercase text-slate-500 tracking-wider mb-3 flex items-center gap-1.5">
                      <User className="w-3.5 h-3.5 text-blue-400" />
                      Customer Details
                    </h4>
                    <div className="space-y-2">
                      <div className="text-white font-semibold text-sm">{selectedBooking.user_name || "Unknown"}</div>
                      <div className="text-slate-400 text-xs flex items-center gap-1">
                        <Phone className="w-3 h-3 text-slate-600" />
                        {selectedBooking.user_phone || "No phone listed"}
                      </div>
                      <div className="text-slate-500 text-[11px] font-mono">
                        Citizen ID: {selectedBooking.citizen_id || "citizen_demo"}
                      </div>
                    </div>
                  </div>

                  {/* Provider Card */}
                  <div className="bg-slate-950/50 border border-slate-800/80 rounded-xl p-4">
                    <h4 className="text-xs font-bold uppercase text-slate-500 tracking-wider mb-3 flex items-center gap-1.5">
                      <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
                      Assigned Professional
                    </h4>
                    {selectedProvider ? (
                      <div className="space-y-2">
                        <div className="text-white font-semibold text-sm flex items-center gap-1">
                          {selectedProvider.name_en}
                          {selectedProvider.cnic_verified && (
                            <span className="text-[10px] px-1.5 py-0.5 bg-blue-500/20 text-blue-400 rounded-full font-bold">
                              CNIC Verified
                            </span>
                          )}
                        </div>
                        <div className="text-slate-400 text-xs flex items-center justify-between">
                          <span className="flex items-center gap-1">
                            <Phone className="w-3 h-3 text-slate-600" />
                            {selectedProvider.phone || "No phone listed"}
                          </span>
                          <span className="text-amber-400 font-medium">⭐ {selectedProvider.rating || "5.0"}</span>
                        </div>
                        <div className="text-slate-500 text-[11px] font-mono">
                          ID: {selectedBooking.provider_id}
                        </div>
                      </div>
                    ) : (
                      <div className="space-y-2">
                        <div className="text-white font-semibold text-sm">
                          {selectedBooking.provider_name || selectedBooking.provider_id || "Searching..."}
                        </div>
                        <div className="text-slate-500 text-xs italic">Loading additional profile details...</div>
                      </div>
                    )}
                  </div>
                </div>

                {/* 2. Schedule & Location Details */}
                <div className="bg-slate-950/20 border border-slate-800/40 rounded-xl p-4 space-y-3">
                  <h4 className="text-xs font-bold uppercase text-slate-500 tracking-wider flex items-center gap-1.5">
                    <MapPin className="w-3.5 h-3.5 text-red-400" />
                    Appointment Details
                  </h4>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs">
                    <div>
                      <div className="text-slate-500 mb-1">Appointment Time</div>
                      <div className="text-slate-200 font-semibold flex items-center gap-1.5">
                        <Calendar className="w-3.5 h-3.5 text-emerald-400" />
                        {formatScheduledDateTime(selectedBooking.scheduled_date, selectedBooking.scheduled_time)}
                      </div>
                    </div>
                    <div>
                      <div className="text-slate-500 mb-1">Address & Coordinates</div>
                      <div className="text-slate-200 font-semibold truncate">
                        {selectedBooking.service_address || selectedBooking.service_area || "Gulberg, Lahore"}
                      </div>
                      {selectedBooking.service_lat && selectedBooking.service_lng && (
                        <div className="text-blue-400 font-mono text-[10px] mt-0.5">
                          Coordinates: {Number(selectedBooking.service_lat).toFixed(6)}, {Number(selectedBooking.service_lng).toFixed(6)}
                        </div>
                      )}
                    </div>
                  </div>
                  {selectedBooking.original_input && (
                    <div className="pt-2 border-t border-slate-800/40 mt-1">
                      <div className="text-slate-500 text-xs mb-1">Original User Input</div>
                      <div className="text-slate-400 italic text-xs bg-slate-950/50 p-2.5 rounded-lg border border-slate-800/80">
                        "{selectedBooking.original_input}"
                      </div>
                    </div>
                  )}
                </div>

                {/* 3. TEE & Blockchain Telemetry */}
                <div className="border border-slate-800 rounded-xl p-4 bg-slate-950/40 space-y-3">
                  <div className="flex justify-between items-center">
                    <h4 className="text-xs font-bold uppercase text-slate-500 tracking-wider flex items-center gap-1.5">
                      <Shield className="w-3.5 h-3.5 text-emerald-400" />
                      Security & Blockchain Ledger
                    </h4>
                    <span className="text-[10px] px-2 py-0.5 bg-emerald-500/20 text-emerald-400 font-bold rounded-full flex items-center gap-1">
                      <CheckSquare className="w-3 h-3" /> TEE Verified
                    </span>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-3 gap-3 text-xs">
                    <div className="bg-slate-900 border border-slate-800 rounded-lg p-2.5">
                      <div className="text-slate-500 text-[10px] mb-0.5">Escrow State</div>
                      <div className={`font-semibold ${selectedBooking.escrow_active ? "text-emerald-400" : "text-slate-400"}`}>
                        {selectedBooking.escrow_active ? "Escrow Funded" : "Escrow Pending"}
                      </div>
                    </div>
                    <div className="bg-slate-900 border border-slate-800 rounded-lg p-2.5">
                      <div className="text-slate-500 text-[10px] mb-0.5">Payment Method</div>
                      <div className="text-slate-200 font-semibold flex items-center gap-1">
                        JazzCash Escrow
                      </div>
                    </div>
                    <div className="bg-slate-900 border border-slate-800 rounded-lg p-2.5">
                      <div className="text-slate-500 text-[10px] mb-0.5">Blockchain Tx Hash</div>
                      <div className="text-emerald-400 font-mono text-[10px] truncate">
                        {selectedBooking.blockchain_tx_hash ? selectedBooking.blockchain_tx_hash.substring(0,10) + "..." : "Pending Agreement"}
                      </div>
                    </div>
                  </div>

                  {selectedBooking.blockchain_tx_hash && (
                    <div className="text-[10px] text-slate-500 bg-slate-950 p-2 rounded font-mono truncate">
                      TX: {selectedBooking.blockchain_tx_hash}
                    </div>
                  )}
                </div>

                {/* 4. Live Chat supervisor transcript */}
                <div className="border border-slate-800 rounded-xl overflow-hidden flex flex-col bg-slate-950/60">
                  <div className="p-3 bg-slate-950 border-b border-slate-800 flex justify-between items-center">
                    <div className="text-xs font-bold text-slate-400 flex items-center gap-1.5">
                      <MessageSquare className="w-3.5 h-3.5 text-emerald-400" />
                      Live Chat Monitor
                    </div>
                    <span className="text-[10px] text-slate-500 animate-pulse flex items-center gap-1">
                      <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span> Live Monitoring
                    </span>
                  </div>

                  {/* Messages list */}
                  <div className="h-64 overflow-y-auto p-4 space-y-3 bg-slate-950/80">
                    {chatMessages.length === 0 ? (
                      <div className="h-full flex items-center justify-center text-slate-600 text-xs italic">
                        No messages exchanged yet. Click "Send" to broadcast an admin message.
                      </div>
                    ) : (
                      chatMessages.map((m, i) => {
                        const isAdmin = m.sender_id === "admin";
                        const isProvider = m.sender_id === selectedBooking.provider_id || m.sender_id.startsWith("PRV");
                        const senderName = isAdmin ? "SYSTEM/ADMIN" : isProvider ? "PROVIDER" : "CUSTOMER";
                        
                        let isVoice = false;
                        let isAudioPayload = false;
                        let audioSrc = "";
                        let duration = "";
                        let displayVal = m.text;

                        if (m.text && typeof m.text === "string") {
                          if (m.text.startsWith("voice_msg_audio|")) {
                            isVoice = true;
                            isAudioPayload = true;
                            const parts = m.text.split("|");
                            duration = parts[1] || "";
                            const base64Audio = parts[3] || "";
                            audioSrc = getAudioDataUri(base64Audio);
                            displayVal = "🎙️ Voice note received";
                          } else if (m.text.startsWith("voice_msg|")) {
                            isVoice = true;
                            const parts = m.text.split("|");
                            duration = parts[1] || "";
                            displayVal = parts[3] || "";
                          }
                        }
                        
                        return (
                          <div 
                            key={m.id || i}
                            className={`flex flex-col ${
                              isAdmin ? "items-center" : isProvider ? "items-end" : "items-start"
                            }`}
                          >
                            <div className="text-[10px] text-slate-500 mb-0.5 px-1 font-mono">
                              {senderName} • {new Date(m.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                            </div>
                            <div className={`px-3 py-2 rounded-xl text-xs max-w-[80%] ${
                              isAdmin ? "bg-amber-500/20 text-amber-300 border border-amber-500/40 rounded-lg text-center" : 
                              isProvider ? "bg-emerald-600 text-white rounded-br-none" : 
                              "bg-slate-800 text-slate-200 rounded-bl-none"
                            }`}>
                              {isVoice ? (
                                <div className="space-y-2 py-1 min-w-[200px]">
                                  <div className="flex items-center gap-2 text-[11px] font-semibold text-emerald-300">
                                    <span className="animate-pulse">🎙️</span>
                                    <span>Voice Message ({duration}s)</span>
                                  </div>
                                  
                                  <VoicePlayer 
                                    audioSrc={audioSrc} 
                                    duration={duration} 
                                  />
                                </div>
                              ) : (
                                m.text
                              )}
                            </div>
                          </div>
                        );
                      })
                    )}
                    <div ref={chatEndRef} />
                  </div>

                  {/* Message Input box */}
                  <form onSubmit={handleSendAdminMessage} className="p-2 bg-slate-950 border-t border-slate-800 flex gap-2">
                    <input 
                      type="text"
                      value={adminMessage}
                      onChange={(e) => setAdminMessage(e.target.value)}
                      placeholder="Type official broadcast or safety warning..."
                      className="flex-1 bg-slate-900 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500"
                    />
                    <button
                      type="submit"
                      disabled={sendingMessage || !adminMessage.trim()}
                      className="p-1.5 bg-emerald-500 hover:bg-emerald-600 disabled:opacity-50 text-white rounded-lg transition-colors flex items-center justify-center"
                    >
                      <Send className="w-4 h-4" />
                    </button>
                  </form>
                </div>
              </div>
            </div>
          ) : (
            <div className="flex-1 flex flex-col items-center justify-center text-center p-8">
              <div className="p-4 bg-slate-950 border border-slate-800/80 rounded-full mb-4 animate-bounce">
                <Wrench className="w-10 h-10 text-emerald-400" />
              </div>
              <h3 className="text-lg text-white font-bold mb-1">No Selection</h3>
              <p className="text-slate-500 text-sm max-w-sm">
                Select a booking from the left sidebar to view live maps, trust profiles, and real-time moderated chats.
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

interface VoicePlayerProps {
  audioSrc?: string;
  duration: string;
}

function VoicePlayer({ audioSrc, duration }: VoicePlayerProps) {
  const [playing, setPlaying] = useState(false);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  useEffect(() => {
    return () => {
      if (audioRef.current) {
        audioRef.current.pause();
      }
    };
  }, []);

  if (!audioSrc) {
    return (
      <div className="text-[11px] text-slate-500 italic p-2 bg-slate-900/40 rounded border border-slate-800">
        Voice data not available
      </div>
    );
  }

  const togglePlay = () => {
    if (!audioRef.current) return;
    if (playing) {
      audioRef.current.pause();
      setPlaying(false);
    } else {
      audioRef.current.play()
        .then(() => setPlaying(true))
        .catch(err => console.error("Audio play failed:", err));
    }
  };

  return (
    <div className="mt-1 bg-slate-900/60 rounded-lg p-2 border border-slate-700/40 flex items-center gap-3 justify-between">
      <audio
        ref={audioRef}
        src={audioSrc}
        onEnded={() => setPlaying(false)}
        onPause={() => setPlaying(false)}
        className="hidden"
      />
      <button 
        type="button"
        onClick={togglePlay}
        className="flex items-center justify-center w-8 h-8 rounded-full bg-emerald-500 hover:bg-emerald-600 text-white transition-colors cursor-pointer shadow-md shadow-emerald-500/20 active:scale-95 duration-100"
      >
        {playing ? (
          <svg className="w-3.5 h-3.5 fill-current" viewBox="0 0 24 24">
            <rect x="4" y="4" width="4" height="16" rx="1"/>
            <rect x="16" y="4" width="4" height="16" rx="1"/>
          </svg>
        ) : (
          <svg className="w-3.5 h-3.5 fill-current ml-0.5" viewBox="0 0 24 24">
            <path d="M8 5v14l11-7z"/>
          </svg>
        )}
      </button>
      <div className="flex-1 text-[11px] text-slate-300 font-medium">
        {playing ? "Playing original voice note..." : `Listen to original voice (${duration}s)`}
      </div>
      <div className="flex items-center gap-0.5 h-4">
        <span className={`w-0.5 h-2.5 bg-emerald-400 rounded-full ${playing ? "animate-bounce" : "opacity-60"}`} style={{ animationDelay: '0.075s' }}></span>
        <span className={`w-0.5 h-4 bg-emerald-400 rounded-full ${playing ? "animate-bounce" : "opacity-60"}`} style={{ animationDelay: '0.15s' }}></span>
        <span className={`w-0.5 h-3 bg-emerald-400 rounded-full ${playing ? "animate-bounce" : "opacity-60"}`} style={{ animationDelay: '0s' }}></span>
        <span className={`w-0.5 h-2 bg-emerald-400 rounded-full ${playing ? "animate-bounce" : "opacity-60"}`} style={{ animationDelay: '0.22s' }}></span>
      </div>
    </div>
  );
}

