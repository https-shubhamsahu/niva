import { useEffect, useRef, useState } from "react";
// @ts-ignore
import simpleheat from "simpleheat";

interface FootHeatmapProps {
  sensors: { sensor: string; val: number }[];
  isConnected: boolean;
}

export default function FootHeatmap({ sensors, isConnected }: FootHeatmapProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  
  // We match the canvas dimensions to a standard square aspect ratio 
  // since the uploaded feet image is a square showing both feet.
  const canvasWidth = 400;
  const canvasHeight = 400;

  // X and Y coordinates mapping exactly to the custom foot image you uploaded.
  // The image shows both Left and Right feet, so we mirror the data onto both sides
  // for a symmetrical dashboard demonstration!
  
  const sensorPositions: Record<string, { left: [number, number], right: [number, number] }> = {
    'Hallux':  { left: [135, 60],  right: [265, 60] },
    '1st Met': { left: [120, 130], right: [280, 130] },
    '5th Met': { left: [75, 160],  right: [325, 160] },
    'Heel':    { left: [140, 320], right: [260, 320] },
  };

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    
    const heat = simpleheat(canvas);
    const points: [number, number, number][] = [];
    
    let total = 0;
    let cxLeft = 0, cyLeft = 0;
    let cxRight = 0, cyRight = 0;

    sensors.forEach((s) => {
      const pos = sensorPositions[s.sensor];
      if (pos) {
        // We add slight asymmetric randomization between feet in our simulation
        const valLeft = isConnected ? s.val * (0.8 + Math.random() * 0.4) : 0;
        const valRight = isConnected ? s.val * (0.8 + Math.random() * 0.4) : 0;
        
        points.push([pos.left[0], pos.left[1], valLeft * 100]); 
        points.push([pos.right[0], pos.right[1], valRight * 100]); 
        
        const pL = valLeft || 0;
        const pR = valRight || 0;
        
        total += (pL + pR) / 2;
        cxLeft += pL * pos.left[0];
        cyLeft += pL * pos.left[1];
        cxRight += pR * pos.right[0];
        cyRight += pR * pos.right[1];
      }
    });

    const ctx = canvas.getContext('2d');
    if (ctx) {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
    }
    
    heat.data(points);
    heat.radius(45, 30); 
    heat.max(9000); 
    heat.draw();

    // Draw Biomechanical Center of Pressure (COP) Overlays
    if (total > 0 && isConnected) {
      // Calculate independent COP for Left and Right Foot
      const drawCop = (cx: number, cy: number, color: string) => {
        if (!ctx) return;
        ctx.beginPath();
        ctx.arc(cx, cy, 6, 0, Math.PI * 2);
        ctx.fillStyle = "white";
        ctx.fill();
        ctx.strokeStyle = color;
        ctx.lineWidth = 2.5;
        ctx.stroke();

        ctx.beginPath();
        ctx.moveTo(cx - 14, cy);
        ctx.lineTo(cx + 14, cy);
        ctx.moveTo(cx, cy - 14);
        ctx.lineTo(cx, cy + 14);
        ctx.strokeStyle = "white";
        ctx.lineWidth = 1.5;
        ctx.stroke();
      };
      
      let sumL = 0; let sumR = 0;
      sensors.forEach(s => { 
        sumL += isConnected ? s.val * 1.0 : 0; 
        sumR += isConnected ? s.val * 1.0 : 0; 
      });

      if (sumL > 0) drawCop(cxLeft / sumL, cyLeft / sumL, "rgba(59, 130, 246, 0.8)"); // Blue outline
      if (sumR > 0) drawCop(cxRight / sumR, cyRight / sumR, "rgba(59, 130, 246, 0.8)");
    }

  }, [sensors, isConnected]);

  return (
    <div className="relative w-full aspect-square flex items-center justify-center p-2 rounded-2xl bg-white dark:bg-slate-900 border border-slate-100 dark:border-slate-800/60 overflow-hidden shadow-inner">
      {/* Background Feet Image User Uploaded */}
      <img 
        src="/feet.png" 
        alt="Bilateral Foot Topography" 
        className="absolute inset-0 w-full h-full object-contain p-4 opacity-90 transition-opacity duration-300 pointer-events-none"
        style={{ filter: isConnected ? 'brightness(1)' : 'grayscale(1) brightness(0.6)' }}
      />
      
      {/* Thermal rasterized tracking layer over the feet */}
      <canvas
        ref={canvasRef}
        width={canvasWidth}
        height={canvasHeight}
        className="absolute inset-0 w-full h-full object-contain pointer-events-none z-10 mix-blend-multiply dark:mix-blend-screen"
        style={{
          filter: isConnected ? "saturate(1.2) opacity(90%)" : "grayscale(100%) opacity(20%)",
          transition: "filter 0.5s ease"
        }}
      />
    </div>
  );
}
