"use client";
import { useEffect, useState } from "react";
import { Star, MapPin, BadgeCheck, RefreshCw, X, MessageSquare, Heart, ShieldAlert, Award } from "lucide-react";

import { API_BASE } from "@/utils/api";

export default function ProvidersPage() {
  const [providers, setProviders] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Reviews modal state
  const [selectedProvider, setSelectedProvider] = useState<any | null>(null);
  const [reviews, setReviews] = useState<any[]>([]);
  const [reviewsLoading, setReviewsLoading] = useState(false);

  const fetchProviders = async () => {
    try {
      setIsRefreshing(true);
      const res = await fetch(`${API_BASE}/api/providers/search?limit=50`);
      const data = await res.json();
      setProviders(data.providers || []);
    } catch (err) {
      console.error("Failed to fetch providers:", err);
    } finally {
      setLoading(false);
      setIsRefreshing(false);
    }
  };

  const fetchReviews = async (providerId: string) => {
    try {
      setReviewsLoading(true);
      const res = await fetch(`${API_BASE}/api/providers/${providerId}/reviews`);
      const data = await res.json();
      setReviews(data.reviews || []);
    } catch (err) {
      console.error("Failed to fetch reviews:", err);
      setReviews([]);
    } finally {
      setReviewsLoading(false);
    }
  };

  const openReviewsModal = (provider: any) => {
    setSelectedProvider(provider);
    fetchReviews(provider.id);
  };

  const closeReviewsModal = () => {
    setSelectedProvider(null);
    setReviews([]);
  };

  useEffect(() => {
    fetchProviders();
    const interval = setInterval(fetchProviders, 10000); // Poll every 10 seconds
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="space-y-6">
      <header className="mb-8 flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-bold text-white tracking-tight">Registered Providers</h1>
          <p className="text-slate-400">View and manage all active engineers, technicians, and service providers.</p>
        </div>
        <button 
          onClick={fetchProviders}
          disabled={isRefreshing}
          className="flex items-center gap-2 bg-emerald-600 hover:bg-emerald-500 text-white px-4 py-2.5 rounded-xl font-medium transition-all shadow-lg shadow-emerald-950/20 disabled:opacity-50 active:scale-[0.98]"
        >
          <RefreshCw className={`w-4 h-4 ${isRefreshing ? 'animate-spin' : ''}`} />
          {isRefreshing ? 'Syncing...' : 'Sync Providers'}
        </button>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {loading && providers.length === 0 ? (
          <div className="col-span-full p-12 text-center text-slate-500 flex flex-col items-center justify-center">
            <RefreshCw className="w-8 h-8 animate-spin mb-4 text-emerald-500" />
            Loading providers...
          </div>
        ) : providers.length === 0 ? (
          <div className="col-span-full p-8 text-center text-slate-500 bg-slate-900/50 rounded-xl border border-slate-800">
            No providers found in the system.
          </div>
        ) : (
          providers.map((p) => (
            <div key={p.id} className="bg-slate-900 border border-slate-800 rounded-xl p-6 hover:border-slate-700 transition-all duration-200 relative overflow-hidden group flex flex-col justify-between shadow-md">
              <div>
                <div className="absolute top-0 right-0 p-4 opacity-0 group-hover:opacity-100 transition-opacity">
                   <span className="text-[10px] text-slate-500 font-mono">ID: {p.id?.substring(0, 8)}</span>
                </div>
                <div className="flex justify-between items-start mb-4">
                  <div className="flex items-center gap-4">
                    <div className="w-12 h-12 rounded-full bg-gradient-to-br from-indigo-500 via-purple-500 to-emerald-500 flex items-center justify-center text-white font-bold text-lg shadow-lg">
                      {p.name_en ? p.name_en.charAt(0).toUpperCase() : p.name ? p.name.charAt(0).toUpperCase() : 'P'}
                    </div>
                    <div>
                      <h3 className="text-white font-bold text-lg flex items-center gap-1.5">
                        {p.name_en || p.name || "Unknown"}
                        {p.cnic_verified && <BadgeCheck className="w-4.5 h-4.5 text-blue-400 fill-blue-950/30" />}
                      </h3>
                      <p className="text-emerald-400 text-sm capitalize font-medium">{p.service_type_id?.replace('_', ' ')}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="flex items-center gap-1 text-yellow-400 font-bold bg-yellow-500/5 px-2 py-0.5 rounded-lg border border-yellow-500/10">
                      <Star className="w-3.5 h-3.5 fill-yellow-400" />
                      {p.rating ? parseFloat(p.rating).toFixed(1) : "5.0"}
                    </div>
                    <div className="text-[11px] text-slate-500 mt-1">{p.total_reviews || 0} reviews</div>
                  </div>
                </div>

                <div className="space-y-3 pt-4 border-t border-slate-800/50">
                  <div className="flex justify-between items-center text-sm">
                    <span className="text-slate-500 flex items-center gap-2"><MapPin className="w-4 h-4" /> Area</span>
                    <span className="text-slate-300 font-medium">{p.area_name || "N/A"}</span>
                  </div>
                  <div className="flex justify-between items-center text-sm">
                    <span className="text-slate-500">Rate</span>
                    <span className="text-slate-300 font-bold capitalize">
                      PKR {(() => {
                        const getValidRate = (keys: string[]) => {
                          for (const key of keys) {
                            const val = p[key];
                            if (val !== null && val !== undefined && val !== "" && Number(val) > 0) {
                              return Number(val);
                            }
                          }
                          return 0;
                        };
                        
                        const pType = p.pricing_type || "hourly";
                        let r = 0;
                        if (pType === "fixed") {
                          r = getValidRate(["fixed_rate", "rate", "per_job_rate", "hourly_rate"]);
                          return r > 0 ? r : "N/A";
                        } else if (pType === "per_job") {
                          r = getValidRate(["per_job_rate", "rate", "fixed_rate", "hourly_rate"]);
                          return r > 0 ? r : "N/A";
                        } else {
                          r = getValidRate(["hourly_rate", "rate", "per_job_rate", "fixed_rate"]);
                          return r > 0 ? r : "N/A";
                        }
                      })()}
                      {p.pricing_type === "fixed" ? " (Fixed)" : p.pricing_type === "per_job" ? "/job" : "/hr"}
                    </span>
                  </div>
                  <div className="flex justify-between items-center text-sm">
                    <span className="text-slate-500">Jobs Completed</span>
                    <span className="text-slate-300 font-medium">{p.jobs_completed || 0}</span>
                  </div>
                  <div className="flex justify-between items-center text-sm">
                    <span className="text-slate-500">Trust Badge</span>
                    <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${
                      p.trust_badge === "GOLD" ? "bg-amber-500/10 text-amber-400 border-amber-500/20" :
                      p.trust_badge === "SILVER" ? "bg-slate-400/10 text-slate-300 border-slate-400/20" :
                      "bg-emerald-500/10 text-emerald-400 border-emerald-500/20"
                    }`}>
                      {p.trust_badge || "BRONZE"}
                    </span>
                  </div>
                  <div className="flex justify-between items-center text-sm">
                    <span className="text-slate-500">Gender</span>
                    <span className="text-slate-300 font-medium capitalize">{p.gender || "male"}</span>
                  </div>
                  <div className="flex justify-between items-center text-sm">
                    <span className="text-slate-500">Status</span>
                    <span className={`px-2 py-0.5 rounded-full text-[11px] font-semibold ${p.is_available ? "bg-emerald-500/10 text-emerald-400 border border-emerald-500/20" : "bg-slate-800 text-slate-400 border border-slate-700/50"}`}>
                      {p.is_available ? "Online" : "Offline"}
                    </span>
                  </div>
                </div>
              </div>

              <button
                onClick={() => openReviewsModal(p)}
                className="w-full mt-5 flex items-center justify-center gap-2 bg-slate-800 hover:bg-slate-700 text-slate-200 hover:text-white py-2 rounded-xl text-sm font-semibold transition-all border border-slate-700 hover:border-slate-600 shadow-sm active:scale-[0.98]"
              >
                <Star className="w-4 h-4 text-yellow-500 fill-yellow-500" />
                View Reviews ({p.total_reviews || 0})
              </button>
            </div>
          ))
        )}
      </div>

      {/* Reviews Modal */}
      {selectedProvider && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-md p-4 animate-in fade-in duration-200">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-lg w-full max-h-[85vh] flex flex-col shadow-2xl overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            {/* Modal Header */}
            <div className="p-6 border-b border-slate-800 flex justify-between items-start bg-slate-950/50">
              <div>
                <div className="flex items-center gap-2">
                  <h2 className="text-xl font-bold text-white">{selectedProvider.name_en || selectedProvider.name || "Unknown Professional"}&apos;s Reviews</h2>
                  {selectedProvider.cnic_verified && <BadgeCheck className="w-4.5 h-4.5 text-blue-400" />}
                </div>
                <p className="text-slate-400 text-sm mt-0.5 capitalize">{selectedProvider.service_type_id?.replace('_', ' ')} Provider</p>
              </div>
              <button 
                onClick={closeReviewsModal}
                className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Overall Rating Summary */}
            <div className="px-6 py-4 bg-slate-950/30 border-b border-slate-800/50 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="text-3xl font-extrabold text-white">
                  {selectedProvider.rating ? parseFloat(selectedProvider.rating).toFixed(1) : "5.0"}
                </div>
                <div>
                  <div className="flex text-yellow-400 gap-0.5">
                    {Array.from({ length: 5 }).map((_, i) => (
                      <Star 
                        key={i} 
                        className={`w-4 h-4 ${
                          i < Math.round(parseFloat(selectedProvider.rating || "5.0"))
                            ? "fill-yellow-400"
                            : "text-slate-600"
                        }`} 
                      />
                    ))}
                  </div>
                  <p className="text-xs text-slate-500 mt-0.5">Based on {selectedProvider.total_reviews || 0} customer reviews</p>
                </div>
              </div>
              <div className="text-right">
                <div className="text-xs text-slate-400 font-medium">Completed Jobs</div>
                <div className="text-lg font-bold text-emerald-400">{selectedProvider.jobs_completed || 0}</div>
              </div>
            </div>

            {/* Reviews Content */}
            <div className="p-6 overflow-y-auto flex-1 space-y-4">
              {reviewsLoading ? (
                <div className="py-12 text-center text-slate-500 flex flex-col items-center justify-center">
                  <RefreshCw className="w-8 h-8 animate-spin mb-3 text-emerald-500" />
                  Fetching ratings & commentary...
                </div>
              ) : reviews.length === 0 ? (
                <div className="py-12 text-center text-slate-500 flex flex-col items-center justify-center gap-3">
                  <MessageSquare className="w-12 h-12 text-slate-700" />
                  <div>
                    <p className="text-slate-300 font-bold">No Written Reviews Yet</p>
                    <p className="text-slate-500 text-sm mt-1">This provider hasn&apos;t received written ratings from customers yet.</p>
                  </div>
                </div>
              ) : (
                reviews.map((rev) => {
                  // Determine sentiment styling
                  const isPositive = rev.sentiment_label?.includes("positive");
                  const isNegative = rev.sentiment_label?.includes("negative");
                  let sentimentClass = "bg-slate-800 text-slate-300 border-slate-700";
                  let sentimentIcon = null;

                  if (isPositive) {
                    sentimentClass = "bg-emerald-500/10 text-emerald-400 border-emerald-500/20";
                    sentimentIcon = <Heart className="w-3 h-3 fill-emerald-400" />;
                  } else if (isNegative) {
                    sentimentClass = "bg-rose-500/10 text-rose-400 border-rose-500/20";
                    sentimentIcon = <ShieldAlert className="w-3 h-3" />;
                  }

                  return (
                    <div key={rev.id} className="p-4 rounded-xl bg-slate-950/60 border border-slate-800 hover:border-slate-700/80 transition-colors space-y-2.5">
                      <div className="flex justify-between items-start">
                        <div>
                          <div className="text-white font-bold text-sm flex items-center gap-1.5">
                            {rev.citizen_name || "Anonymous Customer"}
                            <span className="text-[10px] text-slate-500 font-mono font-normal">({rev.citizen_id?.substring(0, 8)})</span>
                          </div>
                          <div className="flex text-yellow-400 gap-0.5 mt-1">
                            {Array.from({ length: 5 }).map((_, i) => (
                              <Star 
                                key={i} 
                                className={`w-3 h-3 ${
                                  i < rev.rating
                                    ? "fill-yellow-400 text-yellow-400"
                                    : "text-slate-700"
                                }`} 
                              />
                            ))}
                          </div>
                        </div>
                        <div className="flex flex-col items-end gap-1">
                          <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold border flex items-center gap-1 capitalize ${sentimentClass}`}>
                            {sentimentIcon}
                            {rev.sentiment_label?.replace('_', ' ') || 'Neutral'}
                          </span>
                          <span className="text-[10px] text-slate-500">
                            {new Date(rev.created_at).toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' })}
                          </span>
                        </div>
                      </div>
                      <p className="text-slate-300 text-sm leading-relaxed">&ldquo;{rev.review_text}&rdquo;</p>
                    </div>
                  );
                })
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

