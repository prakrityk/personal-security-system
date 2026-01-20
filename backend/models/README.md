# Safety Alert App - Database Models

## 📁 Project Structure

```
backend/
├── models/
│   ├── __init__.py          # Exports all models
│   ├── base.py              # Base class and mixins
│   ├── user.py              # User authentication & profile
│   ├── device.py            # FCM/Push notification tokens
│   ├── guardian.py          # Guardian-ward relationships & circles
│   └── emergency.py         # Future: SOS, location, evidence models
├── init_db.py               # Database creation script
└── README.md                # This file
```

## 🗄️ Database Tables

### 1. **users** (user.py)

Main authentication and profile table.

**Columns:**

- `id` - Primary key
- `full_name` - User's full name
- `email` - Unique email for login
- `created_at` - Timestamp
- `updated_at` - Timestamp

**Relationships:**

- One user → Many devices (for push notifications)
- One user → Many relationships (as guardian)
- One user → Many relationships (as ward/dependent)

**Use Cases:**

- Personal Safety Mode users
- Guardian Mode users
- Dependent Mode users (children/elderly)

---

### 2. **devices** (device.py)

Stores FCM/APNs tokens for push notifications.

**Columns:**

- `id` - Primary key
- `user_id` - Foreign key to users
- `device_token` - Unique FCM/APNs token
- `platform` - 'iOS' or 'Android'
- `is_active` - Enable/disable old devices
- `created_at` - Timestamp
- `updated_at` - Timestamp

**Use Cases:**

- Send SOS alerts to emergency contacts
- Guardian notifications for dependent events
- Geofence entry/exit alerts
- Bulk emergency contact notifications

---

### 3. **relationships** (guardian.py)

Links guardian users to their wards (dependents).

**Columns:**

- `id` - Primary key
- `guardian_id` - Foreign key to users (guardian)
- `ward_id` - Foreign key to users (dependent)
- `created_at` - Timestamp
- `updated_at` - Timestamp

**Use Cases:**

- Parent monitoring child's location
- Family member watching elderly relative
- Guardian accessing ward's safety data
- Permission system for dependent monitoring

---

### 4. **guardian_circles** (guardian.py)

Groups for organizing multiple guardians.

**Columns:**

- `id` - Primary key
- `circle_name` - Name of the circle
- `created_at` - Timestamp
- `updated_at` - Timestamp

**Use Cases:**

- Family guardian groups
- Caregiver teams for elderly
- Multiple guardians collaborating

---

### 5. **members** (guardian.py)

Membership in guardian circles.

**Columns:**

- `id` - Primary key
- `guardian_id` - Foreign key to users
- `circle_id` - Foreign key to guardian_circles
- `created_at` - Timestamp
- `updated_at` - Timestamp

**Use Cases:**

- Add guardians to a circle
- Multi-guardian collaborative monitoring
- Team-based dependent care

---

## 🚀 Setup Instructions

### 1. Install Dependencies

```bash
pip install sqlalchemy psycopg2-binary fastapi
```

### 2. Configure Database

Update `DATABASE_URL` in `init_db.py`:

```python
DATABASE_URL = "postgresql://username:password@localhost:5432/safeguard_db"
```

Or set as environment variable:

```bash
export DATABASE_URL="postgresql://your_user:your_pass@localhost:5432/safeguard_db"
```

### 3. Create Tables

```bash
cd backend
python init_db.py
```

### 4. Verify in PostgreSQL

```sql
-- Connect to database
psql -U username -d safeguard_db

-- List all tables
\dt

-- Describe a table
\d users

-- View relationships
\d relationships
```

---

## 🔄 How Models Connect

```
User (Guardian)
    ├── devices (FCM tokens)
    ├── guarding → Relationship → User (Ward/Dependent)
    └── Member → GuardianCircle

User (Ward/Dependent)
    ├── devices (FCM tokens)
    └── guardians → Relationship → User (Guardian)
```

**Example Scenario:**

1. Parent (User #1) creates account
2. Parent adds device token (Device #1) for notifications
3. Parent adds child (User #2) as dependent
4. Creates Relationship (guardian_id=1, ward_id=2)
5. Parent creates "Family Circle" (GuardianCircle #1)
6. Adds spouse as Member to circle
7. Both parents can now monitor child's safety

---

## 📋 Future Models (emergency.py)

When you're ready to add emergency features, create these models:

### **SOSEvent**

- Tracks SOS button presses
- Links to user, location, and trigger type (manual/motion/voice/geofence)

### **EmergencyContact**

- User's designated emergency contacts
- Receives notifications on SOS trigger

### **LocationLog**

- GPS tracking history
- Offline queue for sync when online

### **Geofence**

- Geofence boundaries (home, school, etc.)
- Radius and coordinates

### **GeofenceEvent**

- Entry/exit events
- Triggers notifications to guardians

### **EvidenceMedia**

- Audio/video recordings during SOS
- Automatic evidence collection

### **ThreatDetection**

- AI motion detection events
- Voice activation triggers

---

## 🔧 Usage in FastAPI

```python
from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from models import User, Device, Relationship

app = FastAPI()

# Create a user


# Link device to user


# Create guardian-ward relationship

```

---

## ✅ Advantages of This Structure

1. **Separation of Concerns** - Each file handles specific functionality
2. **Easy Navigation** - Find models quickly by domain
3. **Scalable** - Add new models without cluttering
4. **Maintainable** - Update models independently
5. **Professional** - Shows good software engineering for FYP
6. **Clear Relationships** - Easy to understand data flow

---

## 📝 Next Steps

1. ✅ Set up PostgreSQL database
2. ✅ Run `init_db.py` to create tables
3. ✅ Verify tables exist in PostgreSQL
4. 🔲 Create FastAPI endpoints for user registration
5. 🔲 Implement device token registration
6. 🔲 Add relationship creation endpoint
7. 🔲 Build emergency models (SOS, location, etc.)
8. 🔲 Add authentication (JWT)
9. 🔲 Connect Flutter app to backend

---

## 🎓 FYP Tips

- Document your database design in your report
- Include ER diagram showing relationships
- Explain why you chose this structure
- Show how it supports offline-first design
- Demonstrate guardian protection features
- Highlight scalability for future features
