# api/routes/voice.py
# api/routes/voice.py
import os
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException,Form
from sqlalchemy.orm import Session
from database.connection import get_db
from models.user_voices import UserVoice
import librosa
import numpy as np
import io
from models.user import User
router = APIRouter()

UPLOAD_DIR = "uploads/voices"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/voice/register")
async def register_voice(
    user_id: int,
    sample_number: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    if sample_number not in [1, 2, 3]:
        raise HTTPException(status_code=400, detail="Invalid sample number")

    file_path = f"{UPLOAD_DIR}/user_{user_id}_sample_{sample_number}.wav"

    # save audio file
    with open(file_path, "wb") as f:
        f.write(await file.read())

    try:
        y, sr= librosa.load(file_path, sr=16000)
        mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=129)
        mfcc_mean = np.mean(mfcc, axis=1)

        mfcc_bytes = io.BytesIO()
        np.save(mfcc_bytes, mfcc_mean)
        mfcc_bytes.seek(0)
        mfcc_data = mfcc_bytes.read()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"MFCC extraction failed: {str(e)}")


    # overwrite logic
    existing = db.query(UserVoice).filter_by(
        user_id=user_id,
        sample_number=sample_number
    ).first()

    if existing:
        existing.file_path = file_path
        existing.mfcc_data = mfcc_data

    else:
        voice = UserVoice(
            user_id=user_id,
            sample_number=sample_number,
            file_path=file_path,
            mfcc_data=mfcc_data

        )
        db.add(voice)
    if sample_number == 3:
        user = db.query(User).filter(User.id == user_id).first()
        print(user)
        if user:
            user.is_voice_registered = True
            db.add(user)
            print("usder",user.is_voice_registered)
    db.commit()

    return {
        "message": "Voice sample saved successfully",
        "user_id": user_id,
        "sample_number": sample_number
    }


def get_cosine_similarity(vec1, vec2):
    dot_product = np.dot(vec1, vec2)
    norm_a = np.linalg.norm(vec1)
    norm_b = np.linalg.norm(vec2)
    return dot_product / (norm_a * norm_b)

@router.post("/voice/verify-sos")
async def verify_sos(
    user_id: int = Form(...), 
    file: UploadFile = File(...), 
    db: Session = Depends(get_db)
):
    print(f" Verifying SOS for User {user_id}...")

    # 1. Fetch User's Registered Voice
    stored_voices = db.query(UserVoice).filter(UserVoice.user_id == user_id).all()
    
    if not stored_voices:
        print(" No voice samples found.")
        raise HTTPException(status_code=400, detail="No voice registered")

    # 2. Process Live Audio
    try:
        content = await file.read()
        # Load audio from bytes
        y, sr = librosa.load(io.BytesIO(content), sr=16000)
        
        nn_mfcc=129
        # Extract MFCC
        mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=nn_mfcc)
        live_mfcc_mean = np.mean(mfcc, axis=1) # Shape: (13,)
        
    except Exception as e:
        print(f" Audio Error: {e}")
        raise HTTPException(status_code=500, detail="Invalid audio file")

    # 3. Compare with Stored Samples
    match_found = False
    best_score = 0.0
    THRESHOLD = 0.85 # Adjust this (0.85 is a good starting point)

    for sample in stored_voices:
        try:
            # Load stored MFCC from binary
            stored_bytes = io.BytesIO(sample.mfcc_data)
            stored_mean = np.load(stored_bytes)
            
            # Calculate Similarity
            similarity = get_cosine_similarity(live_mfcc_mean, stored_mean)
            
            if similarity > best_score:
                best_score = similarity

            if similarity >= THRESHOLD:
                match_found = True
                break 

        except Exception as e:
            continue

    # 4. Final Result
    print(f"🔍 Best Match Score: {best_score:.4f}")

    if match_found:
        # TODO: Add logic here to insert into 'sos_logs' table
        return {
            "status": "verified",
            "message": "SOS Activated",
            "score": float(best_score)
        }
    else:
        # Return 401 (Unauthorized) if voice doesn't match
        raise HTTPException(status_code=401, detail="Voice mismatch")