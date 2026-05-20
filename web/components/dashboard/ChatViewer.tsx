"use client";
import { useState, useEffect } from "react";
import { motion } from "framer-motion";

import { API_BASE } from "@/utils/api";

interface ChatMessage {
  id: string;
  sender_id: string;
  text: string;
  timestamp: string;
}

export function ChatViewer({ bookingId }: { bookingId: string }) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let interval: NodeJS.Timeout;
    
    const fetchChat = async () => {
      try {
        const res = await fetch(`${API_BASE}/api/chat/${bookingId}`);
        const data = await res.json();
        if (data.messages) {
          setMessages(data.messages);
        }
      } catch (err) {
        console.error("Error fetching chat:", err);
      } finally {
        setLoading(false);
      }
    };

    fetchChat();
    
    // Poll every 5 seconds for new messages
    interval = setInterval(fetchChat, 5000);
    
    return () => clearInterval(interval);
  }, [bookingId]);

  if (loading) {
    return <div className="text-slate-500 animate-pulse p-4">Loading chat...</div>;
  }

  if (messages.length === 0) {
    return <div className="text-slate-500 p-4">No messages yet.</div>;
  }

  return (
    <div className="flex flex-col gap-2 p-4 h-64 overflow-y-auto bg-slate-950 rounded-lg border border-slate-800">
      {messages.map((msg, i) => {
        const isCustomer = msg.sender_id.startsWith("citizen") || msg.sender_id === "Customer";
        return (
          <motion.div 
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            key={msg.id || i}
            className={`flex flex-col max-w-[80%] ${isCustomer ? 'self-end items-end' : 'self-start items-start'}`}
          >
            <span className="text-xs text-slate-500 mb-1">{isCustomer ? 'Customer' : 'Provider'}</span>
            <div className={`px-3 py-2 rounded-xl text-sm ${isCustomer ? 'bg-indigo-600 text-white rounded-tr-sm' : 'bg-slate-800 text-slate-200 rounded-tl-sm'}`}>
              {msg.text}
            </div>
            {msg.timestamp && (
              <span className="text-[10px] text-slate-600 mt-1">
                {new Date(msg.timestamp).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}
              </span>
            )}
          </motion.div>
        );
      })}
    </div>
  );
}
