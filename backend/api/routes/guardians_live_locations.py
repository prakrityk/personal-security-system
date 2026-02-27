from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from database.connection import get_db
from models.user import User
from models.guardian_dependent import GuardianDependent
from api.utils.auth_utils import get_current_user

router = APIRouter()

@router.get("/guardians_live_locations")
def get_dependents_locations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Returns:
        - All dependents' latest locations only (guardian's location excluded)
        - Includes dependent's full_name
    """

    # 1️⃣ Get dependent IDs
    dependent_ids = db.query(GuardianDependent.dependent_id).filter(
        GuardianDependent.guardian_id == current_user.id
    ).all()
    dependent_ids = [d.dependent_id for d in dependent_ids]

    if not dependent_ids:
        return []

    # 2️⃣ Fetch dependents' latest location along with full_name
    locations_query = text("""
        SELECT DISTINCT ON (ll.user_id)
            ll.user_id,
            ll.latitude,
            ll.longitude,
            ll.updated_at,
            u.full_name
        FROM live_locations ll
        JOIN users u ON ll.user_id = u.id
        WHERE ll.user_id = ANY(:dependent_ids)
        ORDER BY ll.user_id, ll.updated_at DESC
    """)

    dependents_locs = db.execute(
        locations_query,
        {"dependent_ids": dependent_ids}
    ).fetchall()  # Returns list of tuples

    # 3️⃣ Prepare response and debug print
    all_locations = []
    for loc in dependents_locs:
        user_id = loc[0]
        latitude = loc[1]
        longitude = loc[2]
        updated_at = loc[3].isoformat() if loc[3] else ""
        full_name = loc[4]

        # 🔹 Debug print
        print(f"[DEBUG] Dependent ID: {user_id}, Name: {full_name}, Lat: {latitude}, Lng: {longitude}, Updated: {updated_at}")

        all_locations.append({
            "user_id": user_id,
            "latitude": latitude,
            "longitude": longitude,
            "updated_at": updated_at,
            "type": "dependent",
            "dependent_name": full_name
        })

    return all_locations