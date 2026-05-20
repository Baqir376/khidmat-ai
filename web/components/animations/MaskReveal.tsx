"use client";
import { useEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
gsap.registerPlugin(ScrollTrigger);

export function MaskReveal({ children, delay = 0 }: { children: React.ReactNode; delay?: number }) {
  const container = useRef<HTMLDivElement>(null);
  const content = useRef<HTMLDivElement>(null);
  
  useEffect(() => {
    if (!container.current || !content.current) return;
    
    gsap.fromTo(content.current, 
      { y: "100%", rotate: 4 },
      { 
        y: "0%", 
        rotate: 0,
        duration: 1.1,
        delay,
        ease: "power4.out",
        scrollTrigger: {
          trigger: container.current,
          start: "top 90%",
          toggleActions: "play none none reverse"
        }
      }
    );
    
    return () => ScrollTrigger.getAll().forEach(t => t.kill());
  }, [delay]);
  
  return (
    <div ref={container} className="overflow-hidden" style={{ clipPath: "inset(0 0 0 0)" }}>
      <div ref={content}>
        {children}
      </div>
    </div>
  );
}
