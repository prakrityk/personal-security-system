"""
FastAPI application entry point
Personal Security System Backend
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.routes import auth  


# Create FastAPI app
app = FastAPI(
    title="Personal Security System API",
    description="Backend API for personal security and geofencing system",
    version="1.0.0"
)

# Configure CORS (so your Flutter app can connect)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Health check endpoint
@app.get("/")
def read_root():
    return {
        "message": "Personal Security System API",
        "status": "running",
        "version": "1.0.0"
    }


@app.get("/health")
def health_check():
    return {"status": "healthy"}


# TODO: Import and include routers here
# Example:
# from api.routes import auth, users, roles
# app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
# app.include_router(users.router, prefix="/api/users", tags=["Users"])
# app.include_router(roles.router, prefix="/api/roles", tags=["Roles"])

# Include routers
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)