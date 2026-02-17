# api/routes/voice.py
import os
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException
from sqlalchemy.orm import Session
from database.connection import get_db
from models.user_voices import UserVoice
import librosa
import numpy as np
import io


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
        mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
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

    db.commit()

    return {
        "message": "Voice sample saved successfully",
        "user_id": user_id,
        "sample_number": sample_number
    }
