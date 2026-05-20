"use client";
import { useState } from "react";
import { motion, useMotionValue, useTransform } from "framer-motion";

interface Card3DItem {
  id: string;
  title: string;
  subtitle: string;
  background: string;
  icon: string;
}

export function Slider3D({ items }: { items: Card3DItem[] }) {
  const [active, setActive] = useState(1);
  const x = useMotionValue(0);
  
  return (
    <div className="relative flex items-center justify-center h-80" style={{ perspective: "1200px" }}>
      {items.map((item, idx) => {
        const offset = idx - active;
        const isActive = offset === 0;
        
        return (
          <motion.div
            key={item.id}
            className="absolute w-64 h-72 rounded-3xl cursor-pointer select-none"
            style={{ background: item.background }}
            animate={{
              x: offset * 270,
              scale: isActive ? 1 : 0.82,
              zIndex: isActive ? 10 : 5 - Math.abs(offset),
              rotateY: offset * 12,
              opacity: Math.abs(offset) > 2 ? 0 : 1
            }}
            transition={{ type: "spring", stiffness: 300, damping: 30 }}
            onClick={() => setActive(idx)}
            drag={isActive ? "x" : false}
            dragConstraints={{ left: -120, right: 120 }}
            onDragEnd={(_, info) => {
              if (info.offset.x > 80 && active > 0) setActive(active - 1);
              if (info.offset.x < -80 && active < items.length - 1) setActive(active + 1);
            }}
            whileHover={isActive ? { scale: 1.03 } : {}}
          >
            <div className="p-8 h-full flex flex-col justify-between">
              <span className="text-4xl">{item.icon}</span>
              <div>
                <h3 className="text-white text-xl font-semibold">{item.title}</h3>
                <p className="text-white/70 text-sm mt-1">{item.subtitle}</p>
              </div>
            </div>
          </motion.div>
        );
      })}
      
      {/* Navigation dots */}
      <div className="absolute -bottom-8 flex gap-2">
        {items.map((_, i) => (
          <button
            key={i}
            onClick={() => setActive(i)}
            className="transition-all duration-300"
            style={{
              width: active === i ? 24 : 8,
              height: 8,
              borderRadius: 4,
              background: active === i ? "#00C896" : "#334155"
            }}
          />
        ))}
      </div>
    </div>
  );
}
