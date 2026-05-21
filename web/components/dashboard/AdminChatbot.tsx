"use client";
import { useState, useRef, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { MessageSquare, X, Send, Bot, Wrench } from "lucide-react";

import { API_BASE } from "@/utils/api";

interface Message {
  role: "ai" | "user";
  text: string;
}

export function AdminChatbot() {
  const [isOpen, setIsOpen] = useState(false);
  const [messages, setMessages] = useState<Message[]>([
    { 
      role: "ai", 
      text: "Assalam-o-Alaikum Administrator. I am the KaamSaaz Copilot, connected directly to your live database. Ask me any queries about bookings, active provider earnings, or agent reasoning traces." 
    }
  ]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  
  const chatEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (chatEndRef.current) {
      chatEndRef.current.scrollIntoView({ behavior: "smooth" });
    }
  }, [messages, loading]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || loading) return;

    const userMessage = input.trim();
    setInput("");
    
    // Add user's message
    const updatedMessages = [...messages, { role: "user" as const, text: userMessage }];
    setMessages(updatedMessages);
    setLoading(true);

    try {
      const res = await fetch(`${API_BASE}/api/admin/copilot`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: userMessage,
          history: updatedMessages
        }),
      });

      if (!res.ok) {
        throw new Error("Failed to communicate with KaamSaaz Copilot.");
      }

      const data = await res.json();
      let responseText = data.response || "No response received.";

      // Fail-safe cleanup: if backend returns double JSON or stringified JSON format
      if (responseText.trim().startsWith("{") && responseText.trim().endsWith("}")) {
        try {
          const parsed = JSON.parse(responseText);
          if (parsed.response) {
            responseText = parsed.response;
          } else if (parsed.text) {
            responseText = parsed.text;
          }
        } catch (e) {
          // Fallback to raw string if parsing fails
        }
      }

      setMessages(prev => [...prev, { role: "ai" as const, text: responseText }]);
    } catch (err: any) {
      console.error(err);
      setMessages(prev => [
        ...prev, 
        { 
          role: "ai" as const, 
          text: "⚠️ Core connection issue detected. Unable to sync live metrics with Generative AI agent." 
        }
      ]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      {/* Floating Chat Trigger Button - Positioned Top Right */}
      <button 
        onClick={() => setIsOpen(prev => !prev)}
        className="fixed top-6 right-6 w-12 h-12 bg-gradient-to-tr from-emerald-500 to-teal-500 rounded-full shadow-lg shadow-emerald-500/20 flex items-center justify-center text-slate-950 z-[100] hover:scale-105 active:scale-95 transition-all duration-200 border border-emerald-400/20"
        title="Open KaamSaaz Copilot"
        id="copilot-trigger-btn"
      >
        {isOpen ? <X className="w-5 h-5" /> : <MessageSquare className="w-5 h-5" />}
      </button>

      {/* Chat window panel - Aligned under the top right trigger */}
      <AnimatePresence>
        {isOpen && (
          <motion.div 
            initial={{ opacity: 0, y: -20, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -20, scale: 0.95 }}
            transition={{ type: "spring", damping: 25, stiffness: 350 }}
            className="fixed top-20 right-6 w-96 max-w-[calc(100vw-3rem)] bg-slate-900/95 border border-slate-800 rounded-2xl shadow-2xl z-[100] overflow-hidden flex flex-col h-[520px] backdrop-blur-md"
          >
            {/* Header with handyman theme and live pulse */}
            <div className="bg-slate-950 p-4 border-b border-slate-800 flex justify-between items-center">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-lg bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center">
                  <Wrench className="w-4 h-4 text-emerald-400 animate-pulse" />
                </div>
                <div>
                  <h3 className="text-white font-bold text-sm tracking-wide uppercase font-mono">KaamSaaz Copilot</h3>
                  <span className="text-[10px] text-emerald-400 font-mono flex items-center gap-1 uppercase">
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                    Live Telemetry Connected
                  </span>
                </div>
              </div>
              <button 
                onClick={() => setIsOpen(false)} 
                className="text-slate-400 hover:text-white transition-colors"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
            
            {/* Messages Screen */}
            <div className="flex-1 overflow-y-auto p-4 space-y-4 font-mono text-xs">
              {messages.map((msg, i) => (
                <div key={i} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                  <div className={`flex gap-2 max-w-[85%] ${msg.role === 'user' ? 'flex-row-reverse' : 'flex-row'}`}>
                    <div className={`w-6 h-6 rounded-full flex items-center justify-center shrink-0 ${
                      msg.role === 'user' ? 'bg-indigo-500/20 text-indigo-400 border border-indigo-500/20' : 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/20'
                    }`}>
                      {msg.role === 'user' ? 'AD' : 'KP'}
                    </div>
                    <div className={`rounded-xl p-3 leading-relaxed whitespace-pre-wrap ${
                      msg.role === 'user' 
                        ? 'bg-indigo-600 text-white rounded-tr-none shadow-md shadow-indigo-950/20' 
                        : 'bg-slate-800/80 text-slate-100 border border-slate-700/50 rounded-tl-none'
                    }`}>
                      {msg.text}
                    </div>
                  </div>
                </div>
              ))}

              {loading && (
                <div className="flex justify-start">
                  <div className="flex gap-2 items-center">
                    <div className="w-6 h-6 rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/20 flex items-center justify-center shrink-0">
                      KP
                    </div>
                    <div className="bg-slate-800/40 border border-slate-800 rounded-xl p-3 text-slate-400 flex items-center gap-1.5">
                      <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-bounce" style={{ animationDelay: '0ms' }} />
                      <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-bounce" style={{ animationDelay: '150ms' }} />
                      <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-bounce" style={{ animationDelay: '300ms' }} />
                    </div>
                  </div>
                </div>
              )}
              
              <div ref={chatEndRef} />
            </div>
            
            {/* Input Submission */}
            <form onSubmit={handleSubmit} className="p-3 border-t border-slate-800 bg-slate-950/80 flex gap-2">
              <input
                type="text"
                value={input}
                onChange={e => setInput(e.target.value)}
                placeholder="Poochein ya type karein..."
                disabled={loading}
                className="flex-1 bg-slate-900 border border-slate-800 text-white placeholder-slate-500 rounded-xl px-4 py-2.5 text-xs focus:outline-none focus:border-emerald-500 font-mono transition-colors disabled:opacity-50"
              />
              <button 
                type="submit" 
                disabled={loading || !input.trim()}
                className="bg-emerald-500 hover:bg-emerald-400 text-slate-950 rounded-xl p-2.5 transition-colors shrink-0 disabled:opacity-50 disabled:pointer-events-none hover:scale-105 active:scale-95 transition-transform"
              >
                <Send className="w-4 h-4" />
              </button>
            </form>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
