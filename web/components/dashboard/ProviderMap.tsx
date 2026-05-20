"use client";
import dynamic from "next/dynamic";
import { useEffect, useState } from "react";

// Must dynamic-import the entire component that uses Leaflet
// because react-leaflet components can't be individually dynamic-imported
const LeafletMap = dynamic(() => import("./LeafletMapInner"), { ssr: false });

export function ProviderMap() {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) {
    return <div className="h-[400px] w-full bg-slate-800 animate-pulse rounded-xl" />;
  }

  return <LeafletMap />;
}
