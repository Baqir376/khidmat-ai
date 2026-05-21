"use client";

import { useState, useEffect, useCallback } from "react";
import { CheckCircle2, Clock, MapPin, Wrench, AlertTriangle, TrendingUp, Info } from "lucide-react";
import { toast } from "sonner";
import { API_BASE } from "@/utils/api";

const SERVICE_OPTIONS = [
  { value: "electrician", label: "Electrician" },
  { value: "plumber", label: "Plumber" },
  { value: "ac_technician", label: "AC Technician" },
  { value: "ac_mechanic", label: "AC Mechanic" },
  { value: "carpenter", label: "Carpenter" },
  { value: "painter", label: "Painter" },
  { value: "tutor", label: "Tutor / Teacher" },
  { value: "beautician", label: "Beautician" },
  { value: "generator_mechanic", label: "Generator Mechanic" },
  { value: "welder", label: "Welder" },
  { value: "tiler", label: "Tiler / Mason" },
  { value: "house_maid", label: "House Maid" },
  { value: "gardener", label: "Gardener (Mali)" },
  { value: "driver", label: "Driver" },
  { value: "cook", label: "Cook" },
  { value: "cleaner", label: "Cleaner" },
  { value: "mechanic", label: "Mechanic" },
];

interface MarketRange {
  min: number;
  max: number;
  valid?: boolean;
  message?: string;
}

export default function ProviderPortal() {
  const [pendingJobs, setPendingJobs] = useState<any[]>([]);
  const [confirmedJobs, setConfirmedJobs] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [acceptingId, setAcceptingId] = useState<string | null>(null);
  const [providerId, setProviderId] = useState("");
  const [isListening, setIsListening] = useState(false);
  const [activeTab, setActiveTab] = useState<"pending" | "confirmed">("pending");

  const [isRegistering, setIsRegistering] = useState(false);
  const [registerForm, setRegisterForm] = useState({
    name_en: "",
    phone: "",
    service_type_id: "electrician",
    hourly_rate: 1500,
    area_name: "Gulshan",
    gender: "male",
    pricing_type: "hourly",
  });

  // Market price validation state
  const [marketRange, setMarketRange] = useState<MarketRange | null>(null);
  const [rateWarning, setRateWarning] = useState<string | null>(null);
  const [validatingRate, setValidatingRate] = useState(false);

  const fetchJobs = useCallback(async (id: string) => {
    if (!id) return;
    try {
      const [pendingRes, confirmedRes] = await Promise.all([
        fetch(`${API_BASE}/api/bookings?status=pending&provider_id=${id}`),
        fetch(`${API_BASE}/api/bookings?status=confirmed&provider_id=${id}`)
      ]);

      if (!pendingRes.ok || !confirmedRes.ok) {
        console.error("Failed to fetch jobs:", pendingRes.status, confirmedRes.status);
        return;
      }

      const pendingData = await pendingRes.json();
      const confirmedData = await confirmedRes.json();
      setPendingJobs(pendingData.bookings || []);
      setConfirmedJobs(confirmedData.bookings || []);
    } catch (err) {
      console.error("Error fetching jobs:", err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!isListening || !providerId) return;
    fetchJobs(providerId);
    const interval = setInterval(() => fetchJobs(providerId), 5000);
    return () => clearInterval(interval);
  }, [isListening, providerId, fetchJobs]);

  // Validate rate against market whenever relevant fields change
  const validateRate = useCallback(async (serviceTypeId: string, rate: number, areaName: string, pricingType: string) => {
    if (!serviceTypeId || !areaName || rate <= 0) return;
    setValidatingRate(true);
    setRateWarning(null);
    try {
      const res = await fetch(`${API_BASE}/api/providers/validate-rate`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          service_type_id: serviceTypeId,
          rate,
          area_name: areaName,
          pricing_type: pricingType,
        }),
      });
      const data = await res.json();
      setMarketRange({ min: data.min, max: data.max, valid: data.valid !== false, message: data.message });
      if (data.valid === false) {
        setRateWarning(data.message || `Rate should be between PKR ${data.min} – ${data.max} for this service in ${areaName}.`);
      }
    } catch (err) {
      // If backend unreachable, clear warning but don't block
      setMarketRange(null);
      setRateWarning(null);
    } finally {
      setValidatingRate(false);
    }
  }, []);

  useEffect(() => {
    const debounceTimer = setTimeout(() => {
      if (registerForm.service_type_id && registerForm.area_name && registerForm.hourly_rate > 0) {
        validateRate(registerForm.service_type_id, registerForm.hourly_rate, registerForm.area_name, registerForm.pricing_type);
      }
    }, 600);
    return () => clearTimeout(debounceTimer);
  }, [registerForm.service_type_id, registerForm.hourly_rate, registerForm.area_name, registerForm.pricing_type, validateRate]);

  const acceptJob = async (bookingId: string) => {
    setAcceptingId(bookingId);
    try {
      const res = await fetch(`${API_BASE}/api/bookings/${bookingId}/accept`, {
        method: "POST",
      });
      const data = await res.json();
      if (res.ok) {
        toast.success("Job Accepted Successfully!", {
          description: `Moved to My Jobs. Escrow secured.`,
        });
        fetchJobs(providerId);
        setActiveTab("confirmed");
      } else {
        const errMsg = data.detail || "Failed to accept job";
        toast.error("Failed to accept job", { description: errMsg });
      }
    } catch (err) {
      toast.error("Network error", { description: "Could not connect to server. Please try again." });
    } finally {
      setAcceptingId(null);
    }
  };

  const handleRegister = async () => {
    // Client-side validation
    if (!registerForm.name_en.trim()) { toast.error("Please enter your full name"); return; }
    if (!registerForm.phone.trim()) { toast.error("Please enter your phone number"); return; }
    if (!registerForm.area_name.trim()) { toast.error("Please enter your service area"); return; }
    if (registerForm.hourly_rate <= 0) { toast.error("Please enter a valid rate"); return; }

    // Check if rate is out of market range — warn but tell them the correct range
    if (marketRange && !marketRange.valid) {
      toast.error("Rate Out of Market Range", {
        description: marketRange.message || `Please set your rate between PKR ${marketRange.min} and PKR ${marketRange.max} for your service in ${registerForm.area_name}.`,
        duration: 6000,
      });
      return;
    }

    setLoading(true);
    try {
      const res = await fetch(`${API_BASE}/api/providers/register`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name_en: registerForm.name_en,
          phone: registerForm.phone,
          service_type_id: registerForm.service_type_id,
          pricing_type: registerForm.pricing_type,
          hourly_rate: registerForm.pricing_type === "hourly" ? registerForm.hourly_rate : 0,
          per_job_rate: registerForm.pricing_type === "per_job" ? registerForm.hourly_rate : 0,
          fixed_rate: registerForm.pricing_type === "fixed" ? registerForm.hourly_rate : 0,
          rate: registerForm.hourly_rate,
          area_name: registerForm.area_name,
          gender: registerForm.gender,
        }),
      });

      const data = await res.json();

      if (res.ok && data.success) {
        toast.success("Registered Successfully!", {
          description: `Your Provider ID is: ${data.provider_id}. Keep this safe!`,
          duration: 8000,
        });
        setProviderId(data.provider_id);
        setIsRegistering(false);
        setIsListening(true);
      } else {
        // Backend returned an error — extract human-readable message
        const errMsg = typeof data.detail === "string"
          ? data.detail
          : typeof data.detail === "object" && data.detail?.error
            ? data.detail.error
            : "Registration failed. Please try again.";

        // Check if it's a price range error
        if (errMsg.toLowerCase().includes("fair range") || errMsg.toLowerCase().includes("market value")) {
          toast.error("Rate Out of Market Range", {
            description: errMsg,
            duration: 8000,
          });
        } else {
          toast.error("Registration Failed", { description: errMsg });
        }
      }
    } catch (err) {
      toast.error("Network Error", { description: "Could not connect to the server. Please check your internet connection and try again." });
    } finally {
      setLoading(false);
    }
  };

  const activeJobs = activeTab === "pending" ? pendingJobs : confirmedJobs;

  return (
    <div className="min-h-screen bg-neutral-950 text-white p-8 font-sans">
      <div className="max-w-4xl mx-auto">
        <header className="mb-8 border-b border-white/10 pb-6 flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-emerald-400 to-cyan-400">
              Provider Portal
            </h1>
            <p className="text-white/60 mt-2">Manage your incoming requests and active jobs</p>
          </div>
          <div className="flex items-center gap-2">
            {isListening ? (
              <>
                <span className="relative flex h-3 w-3">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                  <span className="relative inline-flex rounded-full h-3 w-3 bg-emerald-500"></span>
                </span>
                <span className="text-sm text-emerald-400 font-medium">Online &amp; Listening</span>
              </>
            ) : (
              <span className="text-sm text-red-400 font-medium">Offline</span>
            )}
          </div>
        </header>

        {!isListening ? (
          isRegistering ? (
            <div className="bg-white/5 border border-white/10 rounded-2xl p-6 max-w-lg mx-auto">
              <h3 className="text-xl font-semibold mb-2 text-center">Register as a Provider</h3>
              <p className="text-white/50 text-sm text-center mb-6">Fill in your details to join the KaamSaaz network</p>

              <div className="space-y-4 mb-6">
                {/* Full Name */}
                <div>
                  <label className="block text-xs text-white/50 mb-1 uppercase tracking-wider">Full Name</label>
                  <input
                    type="text"
                    placeholder="e.g. Ahmed Khan"
                    value={registerForm.name_en}
                    onChange={e => setRegisterForm({ ...registerForm, name_en: e.target.value })}
                    className="w-full bg-black/40 border border-white/10 rounded-lg p-3 text-white placeholder-white/30 focus:border-emerald-500 focus:outline-none transition-colors"
                  />
                </div>

                {/* Phone */}
                <div>
                  <label className="block text-xs text-white/50 mb-1 uppercase tracking-wider">Phone Number</label>
                  <input
                    type="tel"
                    placeholder="e.g. 03001234567"
                    value={registerForm.phone}
                    onChange={e => setRegisterForm({ ...registerForm, phone: e.target.value })}
                    className="w-full bg-black/40 border border-white/10 rounded-lg p-3 text-white placeholder-white/30 focus:border-emerald-500 focus:outline-none transition-colors"
                  />
                </div>

                {/* Service Type */}
                <div>
                  <label className="block text-xs text-white/50 mb-1 uppercase tracking-wider">Service Type</label>
                  <select
                    value={registerForm.service_type_id}
                    onChange={e => setRegisterForm({ ...registerForm, service_type_id: e.target.value })}
                    className="w-full bg-black/40 border border-white/10 rounded-lg p-3 text-white focus:border-emerald-500 focus:outline-none transition-colors"
                  >
                    {SERVICE_OPTIONS.map(opt => (
                      <option key={opt.value} value={opt.value} className="bg-neutral-900">{opt.label}</option>
                    ))}
                  </select>
                </div>

                {/* Area */}
                <div>
                  <label className="block text-xs text-white/50 mb-1 uppercase tracking-wider">Service Area</label>
                  <input
                    type="text"
                    placeholder="e.g. DHA Lahore, Gulshan Karachi, F-8 Islamabad"
                    value={registerForm.area_name}
                    onChange={e => setRegisterForm({ ...registerForm, area_name: e.target.value })}
                    className="w-full bg-black/40 border border-white/10 rounded-lg p-3 text-white placeholder-white/30 focus:border-emerald-500 focus:outline-none transition-colors"
                  />
                </div>

                {/* Gender */}
                <div>
                  <label className="block text-xs text-white/50 mb-1 uppercase tracking-wider">Gender</label>
                  <div className="flex gap-3">
                    {["male", "female"].map(g => (
                      <button
                        key={g}
                        type="button"
                        onClick={() => setRegisterForm({ ...registerForm, gender: g })}
                        className={`flex-1 py-2.5 rounded-lg font-medium text-sm capitalize transition-all border ${registerForm.gender === g ? "bg-emerald-500 border-emerald-500 text-white" : "bg-black/20 border-white/10 text-white/60 hover:bg-white/5"}`}
                      >
                        {g}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Pricing Type */}
                <div>
                  <label className="block text-xs text-white/50 mb-1 uppercase tracking-wider">Pricing Model</label>
                  <div className="flex gap-2">
                    {[
                      { value: "hourly", label: "Per Hour" },
                      { value: "per_job", label: "Per Job" },
                      { value: "fixed", label: "Fixed" },
                    ].map(pt => (
                      <button
                        key={pt.value}
                        type="button"
                        onClick={() => setRegisterForm({ ...registerForm, pricing_type: pt.value })}
                        className={`flex-1 py-2 rounded-lg text-xs font-semibold transition-all border ${registerForm.pricing_type === pt.value ? "bg-emerald-500 border-emerald-500 text-white" : "bg-black/20 border-white/10 text-white/60 hover:bg-white/5"}`}
                      >
                        {pt.label}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Rate */}
                <div>
                  <label className="block text-xs text-white/50 mb-1 uppercase tracking-wider">
                    Your Rate (PKR)
                    {validatingRate && <span className="ml-2 text-emerald-400 text-[10px]">Checking market...</span>}
                  </label>
                  <div className="relative">
                    <span className="absolute left-3 top-1/2 -translate-y-1/2 text-white/40 font-bold text-sm">Rs.</span>
                    <input
                      type="number"
                      min="0"
                      placeholder="e.g. 1500"
                      value={registerForm.hourly_rate || ""}
                      onChange={e => setRegisterForm({ ...registerForm, hourly_rate: parseInt(e.target.value) || 0 })}
                      className={`w-full bg-black/40 border rounded-lg p-3 pl-10 text-white placeholder-white/30 focus:outline-none transition-colors ${rateWarning ? "border-amber-500 focus:border-amber-400" : "border-white/10 focus:border-emerald-500"}`}
                    />
                  </div>

                  {/* Market Range Info */}
                  {marketRange && !validatingRate && (
                    <div className={`mt-2 p-3 rounded-lg flex items-start gap-2 text-xs ${rateWarning ? "bg-amber-500/10 border border-amber-500/20 text-amber-300" : "bg-emerald-500/10 border border-emerald-500/20 text-emerald-300"}`}>
                      {rateWarning ? <AlertTriangle className="w-3.5 h-3.5 shrink-0 mt-0.5" /> : <TrendingUp className="w-3.5 h-3.5 shrink-0 mt-0.5" />}
                      <div>
                        <span className="font-semibold">
                          Market Value Range: PKR {marketRange.min.toLocaleString()} – {marketRange.max.toLocaleString()}
                        </span>
                        {rateWarning && (
                          <p className="mt-0.5 text-amber-400/80">{rateWarning}</p>
                        )}
                        {!rateWarning && (
                          <p className="mt-0.5 text-emerald-400/70">✓ Your rate is within the fair market range</p>
                        )}
                      </div>
                    </div>
                  )}

                  {/* General market info hint */}
                  {!marketRange && !validatingRate && (
                    <p className="mt-1.5 text-[11px] text-white/30 flex items-center gap-1">
                      <Info className="w-3 h-3" />
                      Enter your area and rate to see the fair market price range
                    </p>
                  )}
                </div>
              </div>

              <div className="flex gap-4">
                <button
                  onClick={() => { setIsRegistering(false); setMarketRange(null); setRateWarning(null); }}
                  className="flex-1 bg-white/5 hover:bg-white/10 text-white font-semibold py-3 rounded-lg transition-colors border border-white/10"
                >
                  Back
                </button>
                <button
                  onClick={handleRegister}
                  disabled={loading || !!rateWarning}
                  className="flex-1 bg-emerald-500 hover:bg-emerald-600 disabled:bg-emerald-800 disabled:opacity-60 text-white font-semibold py-3 rounded-lg transition-colors disabled:cursor-not-allowed"
                >
                  {loading ? "Registering..." : rateWarning ? "Fix Rate First" : "Register"}
                </button>
              </div>
            </div>
          ) : (
            <div className="bg-white/5 border border-white/10 rounded-2xl p-6 text-center max-w-md mx-auto">
              <h3 className="text-xl font-semibold mb-4">Enter Provider ID</h3>
              <p className="text-white/60 mb-6 text-sm">Enter your registered PRV-XXX ID to view your jobs.</p>
              <input
                type="text"
                value={providerId}
                onChange={(e) => setProviderId(e.target.value)}
                placeholder="e.g. PRV-A1B2C3D4"
                className="w-full bg-black/40 border border-white/10 rounded-lg p-3 text-white mb-4 focus:outline-none focus:border-emerald-500"
              />
              <button
                onClick={() => {
                  if (providerId.trim()) {
                    setLoading(true);
                    setIsListening(true);
                  } else {
                    toast.error("Please enter a valid Provider ID");
                  }
                }}
                className="w-full bg-emerald-500 hover:bg-emerald-600 text-white font-semibold py-3 rounded-lg transition-colors mb-4"
              >
                Start Listening
              </button>
              <div className="border-t border-white/10 pt-4 mt-2">
                <p className="text-sm text-white/40 mb-2">Don&apos;t have an ID?</p>
                <button
                  onClick={() => setIsRegistering(true)}
                  className="text-emerald-400 hover:text-emerald-300 font-medium"
                >
                  Register as a new Provider
                </button>
              </div>
            </div>
          )
        ) : (
          <>
            {/* TABS */}
            <div className="flex gap-4 mb-8">
              <button
                onClick={() => setActiveTab("pending")}
                className={`flex-1 py-3 font-semibold rounded-lg transition-all ${activeTab === "pending" ? "bg-white/10 border border-emerald-500 text-white" : "bg-transparent border border-white/10 text-white/60 hover:bg-white/5"}`}
              >
                Incoming Requests
                {pendingJobs.length > 0 && (
                  <span className="ml-2 bg-emerald-500 text-black px-2 py-0.5 rounded-full text-xs">{pendingJobs.length}</span>
                )}
              </button>
              <button
                onClick={() => setActiveTab("confirmed")}
                className={`flex-1 py-3 font-semibold rounded-lg transition-all ${activeTab === "confirmed" ? "bg-white/10 border border-emerald-500 text-white" : "bg-transparent border border-white/10 text-white/60 hover:bg-white/5"}`}
              >
                My Jobs (Confirmed)
                {confirmedJobs.length > 0 && (
                  <span className="ml-2 bg-emerald-500 text-black px-2 py-0.5 rounded-full text-xs">{confirmedJobs.length}</span>
                )}
              </button>
            </div>

            {loading && activeJobs.length === 0 ? (
              <div className="flex justify-center py-20 text-white/40">Loading jobs...</div>
            ) : activeJobs.length === 0 ? (
              <div className="text-center py-20 border border-dashed border-white/10 rounded-2xl bg-white/5">
                <Clock className="mx-auto h-12 w-12 text-white/20 mb-4" />
                <h3 className="text-xl font-semibold text-white/60">
                  {activeTab === "pending" ? "No pending requests right now" : "No confirmed jobs"}
                </h3>
                <p className="text-white/40 mt-2">
                  {activeTab === "pending" ? "Waiting for citizen requests from KaamSaaz..." : "Accept incoming requests to build your schedule."}
                </p>
              </div>
            ) : (
              <div className="grid gap-6">
                {activeJobs.map((job) => (
                  <div key={job.id} className="bg-white/5 border border-white/10 rounded-2xl p-6 transition-all hover:bg-white/10 shadow-lg">
                    <div className="flex justify-between items-start mb-6">
                      <div>
                        <div className="flex items-center gap-3 mb-2">
                          <span className={`text-xs px-3 py-1 rounded-full font-medium border ${activeTab === "pending" ? "bg-emerald-500/20 text-emerald-400 border-emerald-500/20" : "bg-blue-500/20 text-blue-400 border-blue-500/20"}`}>
                            {activeTab === "pending" ? "NEW JOB" : "CONFIRMED JOB"}
                          </span>
                          <span className="text-white/40 text-sm font-mono">{job.id}</span>
                        </div>
                        <h2 className="text-2xl font-semibold flex items-center gap-2">
                          <Wrench className="h-5 w-5 text-emerald-400" />
                          {(job.service_type_id || "").replace(/_/g, " ").toUpperCase()}
                        </h2>
                        {job.original_input && (
                          <p className="text-white/60 italic mt-2 text-sm">&ldquo;{job.original_input}&rdquo;</p>
                        )}
                      </div>
                      <div className="text-right">
                        <p className="text-3xl font-bold text-emerald-400">PKR {job.final_price || job.quoted_price || "TBD"}</p>
                        <p className="text-sm text-white/40">{activeTab === "pending" ? "Quoted Price" : "Final Price"}</p>
                      </div>
                    </div>

                    <div className="bg-white/5 rounded-xl p-4 mb-6 border border-white/5">
                      <h4 className="text-xs font-semibold text-white/60 uppercase tracking-wider mb-3 flex items-center justify-between">
                        <span>Customer Profile</span>
                        {job.womens_safety_mode && (
                          <span className="bg-pink-500/20 text-pink-400 text-[10px] px-2 py-0.5 rounded-full border border-pink-500/30 font-medium">
                            🛡️ Women&apos;s Safety Enabled
                          </span>
                        )}
                      </h4>
                      <div className="grid grid-cols-2 gap-4 text-sm">
                        <div>
                          <p className="text-xs text-white/40">Name</p>
                          <p className="font-medium text-white/95">{job.user_name || "Customer"}</p>
                        </div>
                        <div>
                          <p className="text-xs text-white/40">Contact Phone</p>
                          <p className="font-medium text-emerald-400 font-mono">{job.user_phone || "Not provided"}</p>
                        </div>
                      </div>
                    </div>

                    <div className="grid grid-cols-2 gap-4 mb-8">
                      <div className="flex items-center gap-3 bg-black/40 p-4 rounded-xl border border-white/5">
                        <MapPin className="h-5 w-5 text-blue-400" />
                        <div>
                          <p className="text-xs text-white/40">Location</p>
                          <p className="font-medium text-sm text-white/90">{job.service_address || job.service_area || "Not provided"}</p>
                          {job.service_lat && job.service_lng && (
                            <p className="text-xs text-blue-400/80 font-mono mt-1">
                              {Number(job.service_lat).toFixed(6)}, {Number(job.service_lng).toFixed(6)}
                            </p>
                          )}
                        </div>
                      </div>
                      <div className="flex items-center gap-3 bg-black/40 p-4 rounded-xl border border-white/5">
                        <Clock className="h-5 w-5 text-orange-400" />
                        <div>
                          <p className="text-xs text-white/40">Scheduled Time</p>
                          <p className="font-medium text-sm text-white/90">{job.scheduled_date || "Today"} at {job.scheduled_time || "ASAP"}</p>
                        </div>
                      </div>
                    </div>

                    {activeTab === "pending" ? (
                      <div className="flex gap-4">
                        <button
                          onClick={() => acceptJob(job.id)}
                          disabled={acceptingId === job.id}
                          className="flex-1 bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-400 hover:to-emerald-500 text-white font-semibold py-4 rounded-xl flex items-center justify-center gap-2 transition-all disabled:opacity-50"
                        >
                          {acceptingId === job.id ? (
                            "Accepting & Securing Escrow..."
                          ) : (
                            <>
                              <CheckCircle2 className="h-5 w-5" />
                              ACCEPT JOB
                            </>
                          )}
                        </button>
                        <button className="px-8 py-4 bg-white/5 hover:bg-white/10 text-white/60 font-medium rounded-xl transition-all border border-white/10">
                          Reject
                        </button>
                      </div>
                    ) : (
                      <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-xl p-4 flex items-center justify-center gap-2">
                        <CheckCircle2 className="h-6 w-6 text-emerald-400" />
                        <span className="text-emerald-400 font-semibold text-lg">Job Confirmed &amp; Escrow Funded</span>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
