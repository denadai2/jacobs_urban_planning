# Instructions to add custom data
The instructions are tailored for Italian cities. However, you can edit the database for your necessity.

## Requirements
Then we assume these software dependencies:
* [PostgreSQL 10.0](https://www.postgresql.org/) 
* [PostGIS 2.4.1](https://postgis.net) extension
* [intarray](https://www.postgresql.org/docs/10/static/intarray.html) extension
* [osm2pgsql 0.95.0-dev](https://github.com/openstreetmap/osm2pgsql)


## Database initialization

```bash
createdb WWW
psql WWW < install/schema.sql
```

Download the files from [Figshare](https://figshare.com/articles/The_Death_and_Life_of_Great_Italian_Cities_A_Mobile_Phone_Data_Perspective/7447409) and [Harvard dataverse](https://dataverse.harvard.edu/file.xhtml?persistentId=doi:10.7910/DVN/4A5XMN/JOXGNP&version=1.0).
Then, place them in `install`. Then: 

```bash
createdb WWW
psql WWW < install/schema.sql
gunzip < install/census_areas.sql.gz | psql WWW
gunzip < install/istat_indicatori.sql.gz | psql WWW
gunzip < install/istat_industria.sql.gz | psql WWW
tar xzf data.tgz
```


## Run the code with Italian cities

In all the code and files I assume that each city has a code (named `pro_com`) and each neighborhood has an ID called `ace`.


### Census data
First, it is necessary to import the ISTAT census. There are two ways to do it: manually, automatically (suggested!).

#### Manual import

Import all files from https://www.istat.it/it/archivio/104317 ("Censimento della popolazione e delle abitazioni (formato xls-csv)")

First you download everything and unpack. Then you merge all files into a single one, discarding the headers of the CSV.

```bash
{ head -n1 Sezioni\ di\ Censimento/R01_indicatori_2011_sezioni.csv; for f in Sezioni\ di\ Censimento/R*.csv; do tail -n+2 "$f"; done; } > import_ISTAT.csv
```

Then you import the files

```bash
csvsql --db postgresql://localhost:5432/WWW -v -e iso-8859-1 --table istat_indicatori --create-if-not-exists --no-constraints --insert import_ISTAT.csv
```

And you do the same for Censimento dell'industria e dei servizi (formato txt)

```bash
{ head -n1 Dati_SCE_2011/Sez_AttivitaEconomica/01_AttEcon_SCE_2011.txt; for f in Dati_SCE_2011/Sez_AttivitaEconomica/*2011.txt; do tail -n+2 "$f"; done; } > import_ISTAT.csv
```

Now it's time to import the shapefiles. You should download the data from https://www.istat.it/it/archivio/104317 under the subsection "BASI TERRITORIALI", and the column WGS84 2011.

```bash
ogr2ogr -f "PostgreSQL" PG:"host=localhost user=[youruser] dbname=WWW" -nlt GEOMETRY -nln census_areas [path_shapefile_to_import]
```


#### Automatic import

Download the files from [Figshare](https://figshare.com/articles/The_Death_and_Life_of_Great_Italian_Cities_A_Mobile_Phone_Data_Perspective/7447409) and place them in `install`. Then: 

```bash
gunzip < install/census_areas.sql.gz | psql WWW
gunzip < install/istat_indicatori.sql.gz | psql WWW
gunzip < install/istat_industria.sql.gz | psql WWW
```

### Boundaries
You need to place some shapefiles that act as boundaries of the city. These shapefiles have to contain one multi-polygon. They have to be placed in `data/shps/boundaries/[cityname].shp`. 
If you start from the shapefiles of the Italian census, you can create them dissolving by the `procom` variable, otherwise you can download them from other sources (e.g. from OpenStreetMap). I placed an example of boundary in `data/shps/boundaries/milano.*`.

### Land-use

Download satellite shapefiles from https://land.copernicus.eu/local/urban-atlas/urban-atlas-2012/view. Extract them, and place them into `data/shps/atlas`

### OpenStreetMap

You should download an extract (pbf file) and place it in `data/OSM/[cityname].pbf`. For Italy I suggest https://www.nextzen.org/ or https://www.geofabrik.de/data/download.html.

### Companies

The format of the files to be placed in `data/companies/[cityname].csv` is:
```
long,lat,dimension
9.18886313,45.48014083,piccola
```

### Foursquare

We used Foursquare data to identify the Point Of Interests (POIs) in a city. This can be substituted with other sources of data, like OSM POIs. However, we specified in `install/f4sq_categories.py` the categories we used in Foursquare. We suggest to use [Places API](https://developer.foursquare.com/places-api) to download the data.

The format of the files to be placed in `data/POIs/[cityname].csv` is:
```
lon,lat,category,name,venueID
9.18886313,45.48014083,Art-night,prova,ChIJ0VBVCDZ-44kRYmi7ns98fvw
```

### Mobile phone data

Sadly, we can't share the mobile phone dataset we used. However, there are [similar dataset released in Open Data license](https://www.nature.com/articles/sdata201555).

The original, raw, Call Detail Records have to be processed and put in `generated_files/telco.csv`, with this format:
```
pro_com,ace,avg_activity
82053,40,12652.540506399999
```

### List of cities
You have to specify the list of cities you want to process in `list_cities.csv`, with this format:

```
milano,15146
```

(be careful to put the last, empty, line.

### Run the loader
Whenever you are ready, and you placed all the files in the right directories, you can run configure the loader `load_data.bash` (variables on the top of the file), the loader:

```bash
bash load_data.bash
```

This script will load the data and refresh the materialized views of the database. Then you can run the python scripts :)

## FAQ
### Why do I get many connections errors with the load script?

Check the DB configuration, it is defaulted as no password. Then, ogr2ogr has some issues when people do not use a password. Check your sudo vi `pg_hba.conf` (usually in `/etc/postgresql/11/main/pg_hba.conf`) and trust local connections, or set a password.

### I get errors of no data in the CSV

Remember to remove all the empty lines of the `.csv` files in `data/companies` and `data/POIs`.