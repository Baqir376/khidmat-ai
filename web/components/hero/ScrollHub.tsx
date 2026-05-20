"use client";
import { useEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
gsap.registerPlugin(ScrollTrigger);

export function ScrollHub({ children }: { children: React.ReactNode }) {
  const hubRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!hubRef.current) return;
    
    // Smooth scroll setup using Lenis in Layout, 
    // Here we just orchestrate sections
    const sections = hubRef.current.querySelectorAll("section");
    
    sections.forEach((sec, i) => {
      gsap.fromTo(sec, 
        { opacity: 0.2, filter: "blur(10px)" },
        {
          opacity: 1,
          filter: "blur(0px)",
          scrollTrigger: {
            trigger: sec,
            start: "top center+=200",
            end: "center center",
            scrub: true
          }
        }
      );
    });

    return () => ScrollTrigger.getAll().forEach(t => t.kill());
  }, []);

  return <div ref={hubRef} className="relative z-10">{children}</div>;
}
