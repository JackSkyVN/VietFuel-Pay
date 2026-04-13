"""
seed_hanoi_stations.py
─────────────────────
Queries the Overpass API (OpenStreetMap) for real gas stations in Hanoi
and inserts them into the PostgreSQL `gas_stations` table.

Usage (from the backend/ directory with venv activated):
    python seed_hanoi_stations.py
"""

import asyncio
import uuid
import sys

import httpx
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

# ── Config ────────────────────────────────────────────────────────────────────

# Reads DATABASE_URL from .env automatically if python-dotenv is installed,
# otherwise falls back to the default local URL.
try:
    from dotenv import load_dotenv
    import os
    load_dotenv()
    DATABASE_URL = os.environ.get(
        "DATABASE_URL",
        "postgresql+asyncpg://postgres:postgres@localhost:5432/smart_refuel"
    )
except ImportError:
    DATABASE_URL = "postgresql+asyncpg://postgres:postgres@localhost:5432/smart_refuel"

# Hanoi bounding box  (south, west, north, east)
BBOX = "20.95,105.70,21.10,105.95"

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

QUERY = f"""
[out:json][timeout:30];
(
  node[amenity=fuel]({BBOX});
  way[amenity=fuel]({BBOX});
);
out center;
"""

# ── Fetch from Overpass ───────────────────────────────────────────────────────

async def fetch_stations():
    print("🌏  Querying Overpass API for Hanoi gas stations…")
    async with httpx.AsyncClient(timeout=40) as client:
        resp = await client.post(OVERPASS_URL, data={"data": QUERY})
        resp.raise_for_status()
        data = resp.json()

    elements = data.get("elements", [])
    stations = []

    for el in elements:
        # ways have a "center" key; nodes use lat/lon directly
        lat = el.get("lat") or (el.get("center") or {}).get("lat")
        lon = el.get("lon") or (el.get("center") or {}).get("lon")
        if not lat or not lon:
            continue

        tags = el.get("tags", {})
        name = (
            tags.get("name")
            or tags.get("brand")
            or tags.get("operator")
            or "Gas Station"
        )
        address = ", ".join(filter(None, [
            tags.get("addr:housenumber"),
            tags.get("addr:street"),
            tags.get("addr:suburb") or tags.get("addr:district"),
            "Hà Nội",
        ])) or "Hà Nội"

        stations.append({
            "id": str(uuid.uuid4()),
            "name": name,
            "address": address,
            "latitude": lat,
            "longitude": lon,
            "status": "OPEN",
        })

    print(f"✅  Found {len(stations)} stations from OSM.")
    return stations

# ── Insert into DB ────────────────────────────────────────────────────────────

async def seed(stations):
    engine = create_async_engine(DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        # Wipe existing demo rows first
        await session.execute(text("DELETE FROM gas_stations"))
        await session.commit()
        print("🗑️   Cleared existing gas_stations rows.")

        inserted = 0
        for s in stations:
            await session.execute(
                text("""
                    INSERT INTO gas_stations (id, name, address, latitude, longitude, status, created_at)
                    VALUES (:id, :name, :address, :latitude, :longitude, :status, NOW())
                    ON CONFLICT (id) DO NOTHING
                """),
                s,
            )
            inserted += 1

        await session.commit()
        print(f"🏁  Inserted {inserted} real Hanoi stations into the database.")

    await engine.dispose()

# ── Main ──────────────────────────────────────────────────────────────────────

async def main():
    try:
        stations = await fetch_stations()
        if not stations:
            print("⚠️  No stations returned. Check your bounding box or internet connection.")
            sys.exit(1)
        await seed(stations)
        print("\n✨  Done! Refresh the map in your Flutter app to see real stations.")
    except httpx.HTTPError as e:
        print(f"❌  HTTP error while querying Overpass: {e}")
        print("    Try again in a few seconds – Overpass may be rate-limiting.")
        sys.exit(1)
    except Exception as e:
        print(f"❌  Error: {e}")
        raise

if __name__ == "__main__":
    asyncio.run(main())
