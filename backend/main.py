"""
FastAPI Application - Personal Security System
Main entry point with Firebase Admin SDK initialization
"""

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from pathlib import Path
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

# Import routers
from api.routes import (
    auth,
    pending_dependent,
    voice,
    guardian,
    dependent,
    emergency_contact,
    guardian_auto_contacts,
    device,
    sos,
    location, 
    guardians_live_locations, # ✅ Include location router
)

# Import Firebase service
from services.firebase_service import get_firebase_service


# ========================================================================
# Lifespan - initialize Firebase on startup
# ========================================================================
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("🚀 Starting Personal Security System API...")
    
    # Initialize Firebase Admin SDK
    get_firebase_service()
    
    print("✅ Application startup complete!")
    yield
    print("👋 Shutting down...")


# ========================================================================
# Create FastAPI app
# ========================================================================
app = FastAPI(
    title="Personal Security System API",
    description="Backend API for Personal Security Mobile App with Firebase Authentication",
    version="2.0.0",
    lifespan=lifespan
)

# ========================================================================
# CORS Configuration
# ========================================================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ⚠️ In production, restrict this to your app domains
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ========================================================================
# Static Files
# ========================================================================
UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
print("✅ Static files mounted at /uploads")

# ========================================================================
# Root & Health Check
# ========================================================================
@app.get("/")
def root():
    """Root endpoint - API health check"""
    return {
        "message": "Personal Security System API",
        "status": "running",
        "version": "2.0.0",
        "firebase_enabled": True
    }


@app.get("/health")
def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "firebase": "initialized"
    }


# ========================================================================
# Include Routers
# ========================================================================
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(pending_dependent.router, prefix="/api/pending-dependent", tags=["Pending Dependent"])
app.include_router(voice.router, prefix="/api/voice", tags=["Voice Activation"])
app.include_router(guardian.router, prefix="/api/guardian", tags=["Guardian"])
app.include_router(dependent.router, prefix="/api/dependent", tags=["Dependent"])
app.include_router(emergency_contact.router, prefix="/api", tags=["Emergency Contact"])
app.include_router(guardian_auto_contacts.router, prefix="/api/guardian", tags=["Guardian Auto Contacts"])
app.include_router(device.router, prefix="/api", tags=["Devices"])
app.include_router(sos.router, prefix="/api", tags=["SOS"])
app.include_router(location.router, prefix="/api", tags=["Location"])  # ✅ Location endpoints
app.include_router(guardians_live_locations.router, prefix="/api", tags=["Guardian Live Locations"])  # ✅ Guardian live locations


# ========================================================================
# Run Uvicorn server (only if running directly)
# ========================================================================
if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True  # Auto-reload on code changes (disable in production)
    )