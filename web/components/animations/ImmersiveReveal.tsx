"use client";
import { useEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
gsap.registerPlugin(ScrollTrigger);

export function ImmersiveReveal({
  children,
  delay = 0,
  direction = "up"
}: {
  children: React.ReactNode;
  delay?: number;
  direction?: "up" | "down" | "left" | "right";
}) {
  const ref = useRef<HTMLDivElement>(null);
  
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    
    const fromVars = {
      opacity: 0,
      y: direction === "up" ? 80 : direction === "down" ? -80 : 0,
      x: direction === "left" ? 80 : direction === "right" ? -80 : 0,
      scale: 0.92,
      filter: "blur(12px)"
    };
    
    gsap.fromTo(el, fromVars, {
      opacity: 1, y: 0, x: 0, scale: 1, filter: "blur(0px)",
      duration: 1.2, delay, ease: "power4.out",
      scrollTrigger: {
        trigger: el, start: "top 85%",
        toggleActions: "play none none reverse"
      }
    });
    
    return () => ScrollTrigger.getAll().forEach(t => t.kill());
  }, [delay, direction]);
  
  return <div ref={ref}>{children}</div>;
}
