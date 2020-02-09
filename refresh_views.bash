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

# Refresh database
for table in istat_sezioni atlas_sezioni atlas_area_novac atlas_railways roads_sezioni roads_roundabout roads_2ways roads_2ways_sezioni roads_roundabout_sezioni roads_union roads_buffered buildings_union buildings_sezioni
do
   echo "REFRESHING MATERIALIZED VIEW $table"
   psql -d WWW -c "REFRESH MATERIALIZED VIEW $table"
done

