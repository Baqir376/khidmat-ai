"""
Khidmat AI — FastAPI Main Entry Point
Serves the complete API for mobile app, web dashboard, and WhatsApp/Telegram bots.
"""  # v2
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from config import config
from routes.booking_routes import router as booking_router
from routes.provider_routes import router as provider_router
from routes.admin_routes import router as admin_router
from routes.webhooks import router as webhooks_router
from routes.chat_routes import router as chat_router
from routes.auth_routes import router as auth_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup: seed database if empty. Errors are non-fatal — falls back to in-memory mode."""
    try:
        from services.firebase_service import is_seeded, seed_service_types
        from models.seed_data import SERVICE_TYPES

        if not await is_seeded():
            print("[Seed] Seeding service taxonomy only...")
            try:
                await seed_service_types(SERVICE_TYPES)
                print("[Seed] Service types seeded successfully")
            except Exception as seed_err:
                print(f"[Seed] WARNING: Could not seed to Firebase ({type(seed_err).__name__}) - running in memory-only mode")
                print("[Seed] TIP: Enable Firestore API at: https://console.firebase.google.com/project/khidmat-ai-e02fb/firestore")
        else:
            print("[Seed] Database already initialized")
    except Exception as e:
        print(f"[Startup] WARNING: Seed check failed ({e}) - continuing anyway")

    yield  # App runs here
    print("[Shutdown] Khidmat AI shutting down")


app = FastAPI(
    title="Khidmat AI",
    description=(
        "Agentic AI Service Orchestrator for Pakistan's Informal Economy. "
        "7-agent pipeline: Intent → Discovery → Matching → Negotiation → "
        "Booking → FollowUp → DemandPrediction."
    ),
    version=config.APP_VERSION,
    lifespan=lifespan,
)

# CORS — allow Flutter app and web dashboard
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routes
app.include_router(booking_router, prefix="/api", tags=["Booking Pipeline"])
app.include_router(provider_router, prefix="/api", tags=["Providers"])
app.include_router(admin_router, prefix="/api", tags=["Admin & Analytics"])
app.include_router(webhooks_router, prefix="/api/webhooks", tags=["Messaging Integrations"])
app.include_router(chat_router, prefix="/api/chat", tags=["Chat System"])
app.include_router(auth_router, prefix="/api", tags=["Authentication"])


@app.get("/")
async def root():
    return {
        "name": config.APP_NAME,
        "version": config.APP_VERSION,
        "status": "running",
        "agents": [
            "IntentAgent", "DiscoveryAgent", "MatchingAgent",
            "NegotiationAgent", "BookingAgent", "FollowUpAgent",
            "DemandPredictionAgent",
        ],
        "endpoints": {
            "booking_pipeline": "POST /api/book",
            "providers_nearby": "GET /api/providers/nearby",
            "provider_search": "GET /api/providers/search",
            "booking_status": "GET /api/bookings/{id}",
            "agent_traces": "GET /api/traces/{session_id}",
            "demand_predictions": "GET /api/demand",
            "health": "GET /api/health",
        },
    }


@app.get("/api/health")
async def health_check():
    return {
        "status": "healthy",
        "app": config.APP_NAME,
        "version": config.APP_VERSION,
        "debug": config.DEBUG,
    }


@app.get("/api/debug/providers")
async def debug_providers():
    """Debug: see all providers in the database."""
    from services.firebase_service import query_collection
    all_providers = await query_collection("providers")
    return {
        "total": len(all_providers),
        "providers": all_providers,
    }


@app.get("/api/debug/providers/{service_type}")
async def debug_providers_by_service(service_type: str):
    """Debug: see providers for a specific service type."""
    from services.firebase_service import get_providers_by_service
    providers = await get_providers_by_service(service_type=service_type)
    return {
        "service_type": service_type,
        "total": len(providers),
        "providers": providers,
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=config.HOST,
        port=config.PORT,
        reload=config.DEBUG,
    )
