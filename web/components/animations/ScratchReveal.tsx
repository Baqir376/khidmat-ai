"use client";
import { useState, useRef, useEffect } from "react";

export function ScratchReveal({ hiddenText, revealText }: { hiddenText: string, revealText: string }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [scratched, setScratched] = useState(false);
  
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    
    // Draw cover
    ctx.fillStyle = "#1E293B";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // Draw pattern
    ctx.strokeStyle = "#334155";
    ctx.lineWidth = 2;
    for(let i = 0; i < canvas.width * 2; i+=20) {
      ctx.beginPath();
      ctx.moveTo(i, 0);
      ctx.lineTo(i - canvas.height, canvas.height);
      ctx.stroke();
    }
    
    // Text on cover
    ctx.fillStyle = "#94A3B8";
    ctx.font = "bold 24px Inter, sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(hiddenText, canvas.width/2, canvas.height/2);
    
    let isDrawing = false;
    
    const scratch = (x: number, y: number) => {
      ctx.globalCompositeOperation = "destination-out";
      ctx.beginPath();
      ctx.arc(x, y, 40, 0, Math.PI * 2);
      ctx.fill();
      
      // Check how much is cleared
      const pixels = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
      let transparent = 0;
      for (let i = 3; i < pixels.length; i += 4) {
        if (pixels[i] === 0) transparent++;
      }
      if (transparent / (pixels.length / 4) > 0.4 && !scratched) {
        setScratched(true);
        // Fade out the canvas using CSS transition instead of gsap
        canvas.style.transition = "opacity 0.5s ease";
        canvas.style.opacity = "0";
        setTimeout(() => {
          canvas.style.display = "none";
        }, 500);
      }
    };
    
    const onDown = () => { isDrawing = true; };
    const onUp = () => { isDrawing = false; };
    const onMove = (e: MouseEvent | TouchEvent) => {
      if (!isDrawing) return;
      const rect = canvas.getBoundingClientRect();
      const x = ('clientX' in e ? e.clientX : e.touches[0].clientX) - rect.left;
      const y = ('clientY' in e ? e.clientY : e.touches[0].clientY) - rect.top;
      scratch(x, y);
    };
    
    canvas.addEventListener('mousedown', onDown);
    canvas.addEventListener('mouseup', onUp);
    canvas.addEventListener('mousemove', onMove);
    canvas.addEventListener('touchstart', onDown);
    canvas.addEventListener('touchend', onUp);
    canvas.addEventListener('touchmove', onMove);
    
    return () => {
      canvas.removeEventListener('mousedown', onDown);
      canvas.removeEventListener('mouseup', onUp);
      canvas.removeEventListener('mousemove', onMove);
      canvas.removeEventListener('touchstart', onDown);
      canvas.removeEventListener('touchend', onUp);
      canvas.removeEventListener('touchmove', onMove);
    };
  }, [hiddenText, scratched]);
  
  return (
    <div className="relative rounded-2xl overflow-hidden w-full max-w-md h-32 flex items-center justify-center bg-gradient-to-r from-emerald-500 to-teal-400">
      <h2 className="text-3xl font-bold text-white z-0">{revealText}</h2>
      <canvas
        ref={canvasRef}
        width={400}
        height={128}
        className="absolute top-0 left-0 w-full h-full z-10 cursor-crosshair touch-none"
      />
    </div>
  );
}
