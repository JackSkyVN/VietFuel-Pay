"""
Geofencing utility – validates whether a point is within the station perimeter.
Uses the Haversine formula for accurate great-circle distance calculation.
"""
import math

from app.core.config import get_settings

settings = get_settings()


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Return distance in metres between two GPS coordinates."""
    R = 6_371_000  # Earth radius in metres
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def validate_geofence(
    point_lat: float,
    point_lon: float,
    station_lat: float | None = None,
    station_lon: float | None = None,
    radius_meters: float | None = None,
) -> tuple[bool, float]:
    """
    Check whether a GPS point is within the station geofence.

    Returns:
        (is_valid, distance_in_meters)
    """
    s_lat = station_lat if station_lat is not None else settings.STATION_LAT
    s_lon = station_lon if station_lon is not None else settings.STATION_LON
    radius = radius_meters if radius_meters is not None else settings.GEOFENCE_RADIUS_METERS

    distance = haversine_distance(point_lat, point_lon, s_lat, s_lon)
    return distance <= radius, round(distance, 2)
