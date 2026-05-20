"use client";
import { useEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
gsap.registerPlugin(ScrollTrigger);

export function OnScrollCards({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  
  useEffect(() => {
    if (!ref.current) return;
    const cards = ref.current.children;
    
    gsap.fromTo(cards, 
      { y: 100, opacity: 0, rotateX: -15, transformPerspective: 800 },
      {
        y: 0, opacity: 1, rotateX: 0,
        duration: 0.8,
        stagger: 0.15,
        ease: "back.out(1.2)",
        scrollTrigger: {
          trigger: ref.current,
          start: "top 80%",
        }
      }
    );
  }, []);
  
  return (
    <div ref={ref} className="grid grid-cols-1 md:grid-cols-3 gap-6">
      {children}
    </div>
  );
}
