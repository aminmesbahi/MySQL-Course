/**************************************************************
 * MySQL 8.0 Spatial Data Tutorial
 * This script demonstrates how to work with spatial
 * data in MySQL 8.0 using the OpenGIS-compliant
 * geometry types.  It covers:
 * - Creating tables with POINT, LINESTRING, POLYGON,
 *   and GEOMETRY columns.
 * - Inserting spatial data with ST_GeomFromText (WKT)
 *   and ST_GeomFromGeoJSON.
 * - Creating and using spatial indexes (SRID-bound).
 * - Performing spatial queries: containment, distance,
 *   intersection, and bounding-box checks.
 * - Converting between WKT, WKB, and GeoJSON.
 * - Practical use cases: nearest-neighbour lookup and
 *   point-in-polygon.
 **************************************************************/

-------------------------------------------------
-- Region: 0. Initialization
-------------------------------------------------
USE mysql_course;

DROP TABLE IF EXISTS shapes;
DROP TABLE IF EXISTS world_locations;
DROP TABLE IF EXISTS cities;
DROP TABLE IF EXISTS regions;
DROP TABLE IF EXISTS routes;

-------------------------------------------------
-- Region: 1. Creating Tables with Spatial Columns
-------------------------------------------------
/*
  1.1 Table for 2-D planar geometry shapes (SRID 0 = unitless plane).
*/
CREATE TABLE shapes
(
    shape_id   INT          PRIMARY KEY AUTO_INCREMENT,
    shape_name VARCHAR(50)  NOT NULL,
    geom       GEOMETRY     NOT NULL SRID 0
) ENGINE = InnoDB;

/*
  1.2 Table for real-world geographic points (SRID 4326 = WGS 84).
       A SPATIAL INDEX requires the column to be NOT NULL and
       to declare a fixed SRID in MySQL 8.0.
*/
CREATE TABLE world_locations
(
    location_id   INT         PRIMARY KEY AUTO_INCREMENT,
    location_name VARCHAR(100) NOT NULL,
    geo_point     POINT       NOT NULL SRID 4326,
    SPATIAL INDEX sx_world_locations (geo_point)
) ENGINE = InnoDB;

/*
  1.3 City points.
*/
CREATE TABLE cities
(
    city_id    INT         PRIMARY KEY AUTO_INCREMENT,
    city_name  VARCHAR(100) NOT NULL,
    country    VARCHAR(60)  NOT NULL,
    population INT,
    location   POINT        NOT NULL SRID 4326,
    SPATIAL INDEX sx_cities (location)
) ENGINE = InnoDB;

/*
  1.4 Regions as polygons.
*/
CREATE TABLE regions
(
    region_id   INT          PRIMARY KEY AUTO_INCREMENT,
    region_name VARCHAR(100) NOT NULL,
    country     VARCHAR(60)  NOT NULL,
    boundary    POLYGON      NOT NULL SRID 4326,
    SPATIAL INDEX sx_regions (boundary)
) ENGINE = InnoDB;

/*
  1.5 Routes as linestrings.
*/
CREATE TABLE routes
(
    route_id   INT          PRIMARY KEY AUTO_INCREMENT,
    route_name VARCHAR(100) NOT NULL,
    route_type VARCHAR(50),
    path       LINESTRING   NOT NULL SRID 4326,
    SPATIAL INDEX sx_routes (path)
) ENGINE = InnoDB;

-------------------------------------------------
-- Region: 2. Inserting Spatial Data
-------------------------------------------------
/*
  2.1 Planar shapes using Well-Known Text (WKT).
*/
INSERT INTO shapes (shape_name, geom)
VALUES
    ('Simple Point',   ST_GeomFromText('POINT(3 4)',       0)),
    ('Simple Line',    ST_GeomFromText('LINESTRING(0 0, 5 5, 10 0)', 0)),
    ('Square',         ST_GeomFromText('POLYGON((0 0, 10 0, 10 10, 0 10, 0 0))', 0)),
    ('Donut',          ST_GeomFromText(
        'POLYGON((0 0, 10 0, 10 10, 0 10, 0 0),(2 2, 8 2, 8 8, 2 8, 2 2))', 0)),
    ('MultiPoint',     ST_GeomFromText('MULTIPOINT((0 0),(5 5),(10 10))', 0)),
    ('MultiPolygon',   ST_GeomFromText(
        'MULTIPOLYGON(((0 0,5 0,5 5,0 5,0 0)),((10 10,15 10,15 15,10 15,10 10)))', 0));

/*
  2.2 Real-world cities using POINT(longitude latitude)  with SRID 4326.
       Note: MySQL geometry constructor argument order is (X=lon, Y=lat).
*/
INSERT INTO cities (city_name, country, population, location)
VALUES
    ('New York',   'US', 8336817,
        ST_GeomFromText('POINT(-74.0060 40.7128)', 4326)),
    ('London',     'UK', 8982000,
        ST_GeomFromText('POINT(-0.1278 51.5074)',  4326)),
    ('Tokyo',      'JP', 13960000,
        ST_GeomFromText('POINT(139.6917 35.6895)', 4326)),
    ('Sydney',     'AU', 5312000,
        ST_GeomFromText('POINT(151.2093 -33.8688)', 4326)),
    ('Paris',      'FR', 2161000,
        ST_GeomFromText('POINT(2.3522 48.8566)',   4326));

/*
  2.3 A simple bounding-box polygon around Western Europe (SRID 4326).
*/
INSERT INTO regions (region_name, country, boundary)
VALUES
    ('Western Europe Approx',
     'EU',
     ST_GeomFromText(
         'POLYGON((-10 35, 20 35, 20 60, -10 60, -10 35))', 4326)
    );

/*
  2.4 A simple route.
*/
INSERT INTO routes (route_name, route_type, path)
VALUES
    ('London to Paris',
     'air',
     ST_GeomFromText(
         'LINESTRING(-0.1278 51.5074, 2.3522 48.8566)', 4326));

-------------------------------------------------
-- Region: 3. Converting Between Formats
-------------------------------------------------
/*
  3.1 WKT  → geometry → back to WKT.
*/
SELECT ST_AsText(ST_GeomFromText('POINT(10 20)', 4326)) AS wkt_round_trip;

/*
  3.2 Geometry → GeoJSON.
*/
SELECT ST_AsGeoJSON(location, 4) AS geojson
FROM cities
WHERE city_name = 'New York';

/*
  3.3 GeoJSON → geometry.
*/
SELECT ST_AsText(
    ST_GeomFromGeoJSON('{"type":"Point","coordinates":[-74.006,40.7128]}')
) AS from_geojson;

-------------------------------------------------
-- Region: 4. Spatial Queries
-------------------------------------------------
/*
  4.1 Calculate the straight-line distance (in meters on the ellipsoid)
       between two cities.  ST_Distance_Sphere uses the mean earth radius.
*/
SELECT
    a.city_name AS from_city,
    b.city_name AS to_city,
    ROUND(ST_Distance_Sphere(a.location, b.location) / 1000, 1) AS distance_km
FROM cities a
JOIN cities b ON a.city_id < b.city_id
ORDER BY distance_km;

/*
  4.2 Point-in-polygon: find cities that fall inside the Western Europe region.
*/
SELECT
    c.city_name,
    c.country
FROM cities c
JOIN regions r ON r.region_name = 'Western Europe Approx'
WHERE ST_Within(c.location, r.boundary);

/*
  4.3 Nearest-neighbour: find the three cities closest to a given point
       (latitude 50, longitude 5 – near Belgium).
       ORDER BY distance + LIMIT is efficient when a spatial index exists.
*/
SET @reference = ST_GeomFromText('POINT(5 50)', 4326);

SELECT
    city_name,
    country,
    ROUND(ST_Distance_Sphere(location, @reference) / 1000, 1) AS distance_km
FROM cities
ORDER BY ST_Distance_Sphere(location, @reference)
LIMIT 3;

/*
  4.4 Bounding-box overlap (MBR = Minimum Bounding Rectangle).
       ST_Intersects can use the spatial index via MBR pre-filter.
*/
SET @search_box = ST_GeomFromText(
    'POLYGON((-5 48, 5 48, 5 55, -5 55, -5 48))', 4326);

SELECT city_name, country
FROM cities
WHERE ST_Intersects(location, @search_box);

/*
  4.5 Containment with planar shapes.
*/
SET @big_square = ST_GeomFromText('POLYGON((0 0, 20 0, 20 20, 0 20, 0 0))', 0);

SELECT shape_name
FROM shapes
WHERE ST_Within(geom, @big_square);

-------------------------------------------------
-- Region: 5. Spatial Shape Properties
-------------------------------------------------
/*
  5.1 Geometric properties of planar shapes.
*/
SELECT
    shape_name,
    ST_GeometryType(geom)           AS geom_type,
    ROUND(ST_Area(geom),       2)   AS area,
    ROUND(ST_Perimeter(geom),  2)   AS perimeter,
    ST_IsValid(geom)                AS is_valid
FROM shapes;

/*
  5.2 Route length in degrees (unitless SRID 4326 without geodetic math).
       For metric length use ST_Length with unit parameter (MySQL 8.0.14+).
*/
SELECT
    route_name,
    ROUND(ST_Length(path, 'metre'), 0) AS length_meters
FROM routes;

-------------------------------------------------
-- Region: 6. Importing Spatial Data via GeoJSON
-------------------------------------------------
/*
  6.1 Bulk-load several cities from a JSON array using JSON_TABLE.
*/
SET @geojson_cities = '[
  {"name":"Berlin","country":"DE","lon":13.4050,"lat":52.5200,"pop":3645000},
  {"name":"Madrid","country":"ES","lon":-3.7038,"lat":40.4168,"pop":3223000},
  {"name":"Rome",  "country":"IT","lon":12.4964,"lat":41.9028,"pop":2873000}
]';

INSERT INTO cities (city_name, country, population, location)
SELECT
    j.name,
    j.country,
    j.pop,
    ST_GeomFromText(CONCAT('POINT(', j.lon, ' ', j.lat, ')'), 4326)
FROM JSON_TABLE(
    @geojson_cities,
    '$[*]'
    COLUMNS (
        name    VARCHAR(100) PATH '$.name',
        country VARCHAR(60)  PATH '$.country',
        lon     DOUBLE       PATH '$.lon',
        lat     DOUBLE       PATH '$.lat',
        pop     INT          PATH '$.pop'
    )
) AS j;

SELECT city_name, country, population FROM cities ORDER BY city_id;

-------------------------------------------------
-- Region: 7. Cleanup
-------------------------------------------------
DROP TABLE IF EXISTS routes;
DROP TABLE IF EXISTS regions;
DROP TABLE IF EXISTS cities;
DROP TABLE IF EXISTS world_locations;
DROP TABLE IF EXISTS shapes;

-------------------------------------------------
-- Region: End of Script
-------------------------------------------------
