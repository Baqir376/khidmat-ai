"use client";
import { Canvas, useFrame, useThree } from "@react-three/fiber";
import { Stars, Float, OrbitControls, Sphere } from "@react-three/drei";
import { useRef, useMemo, Suspense } from "react";
import * as THREE from "three";

function ProviderDot({ position }: { position: [number, number, number] }) {
  return (
    <mesh position={position}>
      <sphereGeometry args={[0.04, 8, 8]} />
      <meshStandardMaterial
        color="#00C896"
        emissive="#00C896"
        emissiveIntensity={1.5}
      />
    </mesh>
  );
}

function FloatingGlobe() {
  const groupRef = useRef<THREE.Group>(null);
  useFrame((state) => {
    if (groupRef.current) {
      groupRef.current.rotation.y = state.clock.elapsedTime * 0.08;
    }
  });
  
  const dots = useMemo(() => {
    return Array.from({ length: 80 }, (_, i) => {
      const phi = Math.acos(-1 + (2 * i) / 80);
      const theta = Math.sqrt(80 * Math.PI) * phi;
      return [
        2.6 * Math.sin(phi) * Math.cos(theta),
        2.6 * Math.sin(phi) * Math.sin(theta),
        2.6 * Math.cos(phi)
      ] as [number, number, number];
    });
  }, []);
  
  return (
    <Float speed={1.5} rotationIntensity={0.3} floatIntensity={0.3}>
      <group ref={groupRef}>
        <Sphere args={[2.5, 48, 48]}>
          <meshPhongMaterial
            color="#0F172A"
            transparent
            opacity={0.95}
            wireframe={false}
          />
        </Sphere>
        <Sphere args={[2.52, 32, 32]}>
          <meshBasicMaterial
            color="#1E293B"
            wireframe
            transparent
            opacity={0.2}
          />
        </Sphere>
        {dots.map((pos, i) => (
          <ProviderDot key={i} position={pos} />
        ))}
      </group>
    </Float>
  );
}

export function WebGLScene() {
  return (
    <div style={{ width: "100%", height: "100vh", background: "#0F172A" }}>
      <Canvas camera={{ position: [0, 0, 7], fov: 50 }}>
        <Suspense fallback={null}>
          <ambientLight intensity={0.4} />
          <pointLight position={[10, 10, 5]} intensity={2} color="#00C896" />
          <pointLight position={[-10, -10, -5]} intensity={1} color="#7C3AED" />
          <Stars
            radius={100}
            depth={50}
            count={2000}
            factor={3}
            fade
            speed={0.5}
          />
          <FloatingGlobe />
          <OrbitControls
            enableZoom={false}
            enablePan={false}
            autoRotate={false}
            maxPolarAngle={Math.PI / 2}
            minPolarAngle={Math.PI / 2}
          />
        </Suspense>
      </Canvas>
    </div>
  );
}
