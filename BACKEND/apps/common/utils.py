from django.contrib.gis.geos import Point


def point_from_coords(data):
    if data is None:
        return None
    if isinstance(data, Point):
        return data
    lat = data.get("latitude")
    lng = data.get("longitude")
    if lat is None or lng is None:
        return None
    return Point(float(lng), float(lat), srid=4326)


def point_to_geojson(point):
    if point is None:
        return None
    return {"type": "Point", "coordinates": [point.x, point.y]}


def point_to_latlng(point):
    if point is None:
        return None
    return {"latitude": point.y, "longitude": point.x}
