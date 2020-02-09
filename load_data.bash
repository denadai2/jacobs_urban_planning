#!/usr/bin/env bash
# POSTGRESQL Config
PG_HOST="localhost"
PG_USER="denadai"
PG_DBNAME="WWW"
PG_PORT=5432
PG_STRING="host=$PG_HOST user=$PG_USER dbname=$PG_DBNAME port=$PG_PORT"

# Paths files
DATA_PATH="data" # FULL PATH!
BOUNDARIES_PATH="${DATA_PATH}/shps/boundaries"
ATLAS_PATH="${DATA_PATH}/shps/atlas"
OSM_PATH="${DATA_PATH}/OSM"
COMPANIES_PATH="${DATA_PATH}/companies"
POIS_PATH="${DATA_PATH}/POIs"

set -e
(cat list_of_cities.csv; echo) | while IFS=, read -r city city_code
do
    if [[ $city != "" ]] ; then
        echo "Processing: $city - $city_code"
        # Step 1 import boundary
        ogr2ogr -f "PostgreSQL" PG:"${PG_STRING}" -nlt MULTIPOLYGON -nln temp_boundaries "${BOUNDARIES_PATH}/${city}.shp"
        psql -U ${PG_USER} -d ${PG_DBNAME} -c "INSERT INTO cities (name, pro_com, boundary_geom) SELECT '${city}', ${city_code}, ST_Multi(geom) FROM temp_boundaries"
        psql -U ${PG_USER} -d ${PG_DBNAME} -c "DELETE FROM temp_boundaries"

        # Step 2 import atlas
        ogr2ogr -f "PostgreSQL" PG:"${PG_STRING}" -nlt GEOMETRY -nln temp_atlas "${ATLAS_PATH}/it"*"_${city}.shp"
        psql -U ${PG_USER} -d ${PG_DBNAME} -c "INSERT INTO atlas (code, geom, city) SELECT code, ST_Transform(ST_multi(wkb_geometry), 4326), '${city}' FROM temp_atlas"
        psql -U ${PG_USER} -d ${PG_DBNAME} -c "DELETE FROM temp_atlas"

        # Step 3 import OSM data
        osm2pgsql -W -c -d "${PG_DBNAME}" --port "${PG_PORT}" --host "${PG_HOST}" --username "${PG_USER}" --create --style "${DATA_PATH}/osm2pgsql.style" --multi-geometry --number-processes 2 --latlong -C 30000 "${OSM_PATH}/${city}.pbf"
        psql -U ${PG_USER} -d ${PG_DBNAME} -c "insert into buildings (geom, city, osm_id)
        select st_multi((ST_Dump(way)).geom), '${city}', osm_id from planet_osm_polygon"
        psql -U ${PG_USER} -d ${PG_DBNAME} -c "INSERT INTO roads (area, highway, junction, name, city, geom)
        SELECT area, highway, junction, name, '${city}', (ST_Dump(way)).geom as geom from planet_osm_line
        WHERE highway NOT IN('platform', 'bus_stop', 'motorway', 'motorway_link', 'service', 'footway', 'trunk_link', 'rest_area', 'path', 'primary_link', 'steps', 'proposed', 'construction', 'cycleway', 'track') AND (area IS NULL or area <> 'yes')
        AND (layer <> '-1' OR layer IS NULL);"
        psql -U ${PG_USER} -d ${PG_DBNAME} -c "INSERT INTO railways (geom, city)
        select ST_Multi((ST_Dump(ST_difference(atlas.geom, (select ST_Union(ST_Buffer(way::geography, 500)::geometry) from planet_osm_point p WHERE p.railway='station' AND (p.station <> 'subway' OR p.station IS NULL)) ))).geom) as geom, '${city}'
        from atlas where code = '12230'"
        psql -U ${PG_USER} -d ${PG_DBNAME} -c "INSERT INTO parks (osm_id, geom, geoarea, city)
        SELECT osm_id, st_multi(way), ST_Area(way::geography), '${city}' FROM planet_osm_polygon p WHERE p.leisure = 'park' AND p.barrier IS NULL;"

        # Step 4 import companies
        psql -U ${PG_USER} -d ${PG_DBNAME} -c "\copy companies_temp FROM '${COMPANIES_PATH}/${city}.csv' WITH CSV HEADER;"
        psql -U ${PG_USER} -d ${PG_DBNAME} -c "INSERT INTO companies (long, lat, dimension, geom, city)
        SELECT long, lat, dimension, st_setsrid(st_makepoint(long, lat), 4326), '${city}' FROM companies_temp"
        psql -U ${PG_USER} -d ${PG_DBNAME} -c "DELETE FROM companies_temp"

        # Step 5 import POIs
        psql -U ${PG_USER} -d ${PG_DBNAME} -c "\copy foursquare_venues_temp FROM '${POIS_PATH}/${city}.csv' WITH CSV HEADER;"
        psql -U ${PG_USER} -d ${PG_DBNAME} -c "INSERT INTO foursquare_venues (category, name, venueid, geom, city)
        SELECT category, name, venueid, st_setsrid(st_makepoint(long, lat), 4326), '${city}' FROM foursquare_venues_temp"
        psql -U ${PG_USER} -d ${PG_DBNAME} -c "DELETE FROM foursquare_venues_temp"
    fi
done

# Refresh database
for table in istat_sezioni atlas_sezioni atlas_area_novac atlas_railways roads_sezioni roads_roundabout roads_2ways roads_2ways_sezioni roads_roundabout_sezioni roads_union roads_buffered buildings_union buildings_sezioni
do
   echo "REFRESHING MATERIALIZED VIEW $table"
   psql -d WWW -c "REFRESH MATERIALIZED VIEW $table"
done

