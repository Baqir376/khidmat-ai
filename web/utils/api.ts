const getApiBase = () => {
  if (typeof window !== "undefined") {
    // Allow overriding via query parameter: ?backend=local, ?backend=render, or ?backend=http(s)://url
    const params = new URLSearchParams(window.location.search);
    const backendParam = params.get("backend");
    if (backendParam) {
      if (backendParam === "local") {
        localStorage.setItem("custom_backend_url", "local");
      } else if (backendParam === "render") {
        localStorage.removeItem("custom_backend_url");
      } else if (backendParam.startsWith("http://") || backendParam.startsWith("https://")) {
        // Strip trailing slash if present
        const url = backendParam.endsWith("/") ? backendParam.slice(0, -1) : backendParam;
        localStorage.setItem("custom_backend_url", url);
      }
    }

    const storedBackend = localStorage.getItem("custom_backend_url");
    if (storedBackend === "local") {
      return `http://${window.location.hostname}:8000`;
    } else if (storedBackend && (storedBackend.startsWith("http://") || storedBackend.startsWith("https://"))) {
      return storedBackend;
    }

    // Default: fall back to the production Render backend
    // If the developer wants to connect locally, they can append ?backend=local to the URL.
  }
  return "https://khidmat-ai.onrender.com";
};

export const API_BASE = getApiBase();
