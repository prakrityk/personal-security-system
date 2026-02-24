"""
FastAPI Application - Personal Security System
Main entry point with Firebase Admin SDK initialization
"""
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from pathlib import Path
from fastapi.middleware.cors import CORSMiddleware
from api.routes import auth, pending_dependent
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi import Depends
from api.routes import guardian
from api.routes import dependent
from api.routes import emergency_contact
from api.routes import guardian_auto_contacts
from api.routes import device
from api.routes import sos

from contextlib import asynccontextmanager
import os  # ADD THIS


# Import Firebase service
from services.firebase_service import get_firebase_service

# Import routes (you'll add these)
# from api.routes import auth, guardian, dependent


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan event handler
    Initialize Firebase Admin SDK on startup
    """
    print("🚀 Starting Personal Security System API...")
    
    # Initialize Firebase Admin SDK
    get_firebase_service()
    
    print("✅ Application startup complete!")
    yield
    
    print("👋 Shutting down...")


# Create FastAPI app with lifespan
app = FastAPI(
    title="Personal Security System API",
    description="Backend API for Personal Security Mobile App with Firebase Authentication",
    version="2.0.0",
    lifespan=lifespan
)

# ✅ FIXED CORS - Allow ngrok URLs
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "*",  # For testing - remove in production
        "http://localhost:5000",
        "http://127.0.0.1:5000",
        "http://localhost:8000",
        "https://isaias-nonfermented-odorously.ngrok-free.dev",  # Your CURRENT ngrok URL
        "https://*.ngrok-free.dev",  # Allow all ngrok URLs (wildcard)
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# ✅ FIXED: Use absolute path for uploads directory
# Get the directory where this file is located
BASE_DIR = Path(__file__).resolve().parent
UPLOAD_DIR = BASE_DIR / "uploads"

# Create uploads directory if it doesn't exist
UPLOAD_DIR.mkdir(exist_ok=True)

# Mount static files with absolute path
app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")

print(f"✅ Static files mounted from: {UPLOAD_DIR}")

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


# Include routers
from api.routes import auth,guardian,dependent,pending_dependent

app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(pending_dependent.router, prefix="/api/pending-dependent", tags=["Pending Dependent"])
app.include_router(guardian.router,prefix="/api/guardian",tags=["guardian"])
app.include_router(dependent.router,prefix="/api/dependent",tags=["dependent"])
app.include_router(emergency_contact.router, prefix="/api", tags=["emergency"]) 
app.include_router(guardian_auto_contacts.router, prefix="/api/guardian", tags=["guardian_auto_contacts"])  
app.include_router(device.router, prefix="/api", tags=["devices"])
app.include_router(sos.router, prefix="/api", tags=["sos"])

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True  # Auto-reload on code changes (disable in production)
    )