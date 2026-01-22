# Quick Setup Guide

## 🚀 Get Your Database Running in 5 Minutes

### Step 1: Install PostgreSQL (if not already installed)

**macOS:**
```bash
brew install postgresql
brew services start postgresql
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
```

**Windows:**
Download from https://www.postgresql.org/download/windows/

---

### Step 2: Create Database

```bash
# Connect to PostgreSQL
psql -U postgres

# Inside psql:
CREATE DATABASE safeguard_db;
CREATE USER safeguard_user WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE safeguard_db TO safeguard_user;

# Exit psql
\q
```

---

### Step 3: Clone/Copy Project Files

```bash
cd your-project-directory/backend/
# Copy all files from the outputs folder into your backend directory
```

Your structure should look like:
```
backend/
├── models/
│   ├── __init__.py
│   ├── base.py
│   ├── user.py
│   ├── device.py
│   ├── guardian.py
│   ├── emergency.py
│   └── database.py
├── init_db.py
├── .env.example
├── .gitignore
└── requirements.txt
```

---

### Step 4: Setup Environment Variables

```bash
# Copy the example file
cp .env.example .env

# Edit .env file
nano .env  # or use any text editor
```

Update with your credentials:
```env
DATABASE_URL=postgresql://safeguard_user:your_secure_password@localhost:5432/safeguard_db
```

**Security Tip:** Use a strong password and NEVER commit `.env` to git!

---

### Step 5: Install Python Dependencies

```bash
# Create virtual environment (recommended)
python -m venv venv

# Activate virtual environment
# On macOS/Linux:
source venv/bin/activate
# On Windows:
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

---

### Step 6: Create Database Tables

```bash
# Make sure you're in the backend directory
cd backend

# Run the initialization script
python init_db.py
```

You should see:
```
Connecting to PostgreSQL...
Creating tables...
Successfully created 5 tables: Users, Devices, Relationships, GuardianCircles, Members
```

---

### Step 7: Verify Tables Were Created

```bash
# Connect to your database
psql -U safeguard_user -d safeguard_db

# Inside psql, list all tables:
\dt

# You should see:
#  Schema |      Name         | Type  |     Owner
# --------+-------------------+-------+----------------
#  public | devices           | table | safeguard_user
#  public | guardian_circles  | table | safeguard_user
#  public | members           | table | safeguard_user
#  public | relationships     | table | safeguard_user
#  public | users             | table | safeguard_user

# View structure of a table:
\d users

# Exit
\q
```

---

### Step 8: Test with FastAPI (Optional)

Create a simple `main.py` to test:

```python
from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from models import User
from models.database import get_db

app = FastAPI(title="Safety Alert API")

@app.get("/")
def root():
    return {"message": "Safety Alert API is running!"}

@app.post("/users/")
def create_user(name: str, email: str, db: Session = Depends(get_db)):
    user = User(full_name=name, email=email)
    db.add(user)
    db.commit()
    db.refresh(user)
    return {"id": user.id, "name": user.full_name, "email": user.email}

@app.get("/users/")
def list_users(db: Session = Depends(get_db)):
    users = db.query(User).all()
    return users

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

Run it:
```bash
python main.py
# or
uvicorn main:app --reload
```

Visit: http://localhost:8000/docs for interactive API docs!

---

## 🎯 What You've Accomplished

✅ PostgreSQL database installed and running  
✅ Database created with proper user permissions  
✅ 5 tables created (Users, Devices, Relationships, GuardianCircles, Members)  
✅ Environment variables configured securely  
✅ Python dependencies installed  
✅ Ready to build your FastAPI endpoints!  

---

## 🔥 Common Issues & Solutions

### Issue: "psycopg2-binary" installation fails
**Solution:**
```bash
# macOS
brew install postgresql

# Ubuntu
sudo apt-get install libpq-dev python3-dev

# Then retry
pip install psycopg2-binary
```

### Issue: "Could not connect to database"
**Solution:**
- Check if PostgreSQL is running: `pg_isready`
- Verify credentials in `.env` file
- Check if database exists: `psql -l`

### Issue: "relation already exists"
**Solution:**
Tables already created! To recreate:
```bash
# Drop and recreate
psql -U safeguard_user -d safeguard_db
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO safeguard_user;
\q

# Then run init_db.py again
python init_db.py
```

---

## 📚 Next Steps

1. ✅ Database is ready!
2. 🔲 Create FastAPI endpoints for authentication
3. 🔲 Add JWT token generation
4. 🔲 Implement device registration
5. 🔲 Build guardian-ward relationship endpoints
6. 🔲 Add emergency models (SOS, location, etc.)
7. 🔲 Connect Flutter app to backend
8. 🔲 Test end-to-end flow

---

## 🆘 Need Help?

- PostgreSQL docs: https://www.postgresql.org/docs/
- SQLAlchemy docs: https://docs.sqlalchemy.org/
- FastAPI docs: https://fastapi.tiangolo.com/

Good luck with your FYP! 🚀
