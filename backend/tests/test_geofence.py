"""
Tests for geofencing utility.
"""
import pytest
from app.utils.geofence import haversine_distance, validate_geofence


def test_haversine_same_point():
    """Distance from a point to itself must be zero."""
    d = haversine_distance(10.7769, 106.7009, 10.7769, 106.7009)
    assert d == pytest.approx(0.0, abs=0.01)


def test_haversine_known_distance():
    """Rough sanity check – two points ~1 km apart."""
    # ~1 km north of origin
    d = haversine_distance(10.7769, 106.7009, 10.7859, 106.7009)
    assert 900 < d < 1100


def test_validate_geofence_inside():
    is_valid, distance = validate_geofence(
        point_lat=10.7769,
        point_lon=106.7009,
        station_lat=10.7769,
        station_lon=106.7009,
        radius_meters=300.0,
    )
    assert is_valid is True
    assert distance == pytest.approx(0.0, abs=1.0)


def test_validate_geofence_outside():
    # ~10 km north of station
    is_valid, distance = validate_geofence(
        point_lat=10.8669,
        point_lon=106.7009,
        station_lat=10.7769,
        station_lon=106.7009,
        radius_meters=300.0,
    )
    assert is_valid is False
    assert distance > 300
