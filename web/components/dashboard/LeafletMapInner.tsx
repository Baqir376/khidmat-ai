"use client";
import { useState, useEffect } from "react";
import { MapContainer, TileLayer, CircleMarker, Popup, useMap } from "react-leaflet";
import "leaflet/dist/leaflet.css";

import { API_BASE } from "@/utils/api";

// Dynamic view updater component to automatically fit map bounds to cover all providers
function ChangeView({ providers }: { providers: any[] }) {
  const map = useMap();
  useEffect(() => {
    if (providers.length > 0) {
      const validCoords = providers
        .filter((p) => p.lat && p.lng)
        .map((p) => [p.lat, p.lng] as [number, number]);
      if (validCoords.length > 0) {
        map.fitBounds(validCoords, { padding: [50, 50] });
      }
    }
  }, [providers, map]);
  return null;
}

export default function LeafletMapInner() {
  const defaultCenter: [number, number] = [24.8607, 67.0011];
  const [providers, setProviders] = useState<any[]>([]);

  useEffect(() => {
    fetch(`${API_BASE}/api/providers/search?limit=100`)
      .then((res) => res.json())
      .then((data) => {
        if (data.providers) {
          setProviders(data.providers);
        }
      })
      .catch((err) => console.error("Error fetching providers:", err));
  }, []);

  return (
    <div className="h-[450px] w-full rounded-xl overflow-hidden border border-slate-800">
      <MapContainer center={defaultCenter} zoom={13} style={{ height: "100%", width: "100%" }} zoomControl={false}>
        <TileLayer
          url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>'
        />
        <ChangeView providers={providers} />
        {providers.map((p) => (
          <CircleMarker
            key={p.id}
            center={[p.lat || 24.8607, p.lng || 67.0011]}
            radius={8}
            pathOptions={{ color: "#00C896", fillColor: "#00C896", fillOpacity: 0.7 }}
          >
            <Popup>
              <div className="text-slate-900 font-semibold p-1">
                <div className="font-bold text-base">{p.name_en || p.name}</div>
                <div className="text-emerald-600 text-sm font-semibold">{p.service_type_id}</div>
                <div className="text-slate-500 text-xs mt-1">
                  Location: {p.lat?.toFixed(5)}, {p.lng?.toFixed(5)} ({p.area_name || "Unknown Area"})
                </div>
              </div>
            </Popup>
          </CircleMarker>
        ))}
      </MapContainer>
    </div>
  );
}
