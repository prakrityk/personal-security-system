"""
FastAPI Application - Personal Security System
Main entry point with Firebase Admin SDK initialization
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from api.routes import evidence_routes


# Import Firebase service
from services.firebase_service import FirebaseService

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
    FirebaseService.initialize()
    
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

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app domains
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


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
app.include_router(guardian.router, prefix="/api/guardian", tags=["Guardian"])
app.include_router(dependent.router, prefix="/api/dependent", tags=["Dependent"])
app.include_router(evidence_routes.router, prefix="/api/evidence", tags=["Evidence"])

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True  # Auto-reload on code changes (disable in production)
    )