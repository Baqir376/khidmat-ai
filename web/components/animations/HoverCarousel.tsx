"use client";
import { motion } from "framer-motion";

export function HoverCarousel({ items }: { items: { image: string, title: string }[] }) {
  return (
    <div className="flex gap-4 overflow-x-auto pb-8 hide-scrollbar p-4">
      {items.map((item, i) => (
        <motion.div
          key={i}
          whileHover={{ scale: 1.05, y: -10 }}
          className="min-w-[280px] h-[360px] rounded-2xl relative overflow-hidden flex-shrink-0 cursor-pointer shadow-xl"
        >
          <img src={item.image} alt={item.title} className="absolute inset-0 w-full h-full object-cover" />
          <div className="absolute inset-0 bg-gradient-to-t from-slate-900 via-slate-900/40 to-transparent" />
          <h3 className="absolute bottom-6 left-6 right-6 text-white text-xl font-bold">{item.title}</h3>
        </motion.div>
      ))}
    </div>
  );
}
