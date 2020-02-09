--
-- PostgreSQL database dump
--

-- Dumped from database version 10.0
-- Dumped by pg_dump version 10.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: intarray; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS intarray WITH SCHEMA public;


--
-- Name: EXTENSION intarray; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION intarray IS 'functions, operators, and index support for 1-D arrays of integers';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: atlas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE atlas (
    gid integer NOT NULL,
    code text,
    geom geometry(MultiPolygon,4326),
    city text
);


--
-- Name: census_areas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE census_areas (
    gid integer NOT NULL,
    cod_reg numeric,
    cod_istat numeric,
    pro_com integer,
    sez2011 character varying(13) NOT NULL,
    sez numeric,
    cod_stagno numeric,
    cod_fiume numeric,
    cod_lago numeric,
    cod_laguna numeric,
    cod_val_p numeric,
    cod_zona_c numeric,
    cod_is_amm numeric,
    cod_is_lac numeric,
    cod_is_mar numeric,
    cod_area_s numeric,
    cod_mont_d numeric,
    loc2011 numeric,
    cod_loc numeric,
    tipo_loc numeric,
    com_asc numeric,
    cod_asc character varying(50),
    ace integer,
    shape_leng numeric,
    shape_area numeric,
    geom geometry(MultiPolygon,4326)
);


--
-- Name: cities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE cities (
    name character varying(150) NOT NULL,
    pro_com integer NOT NULL,
    boundary_geom geometry(MultiPolygon,4326)
);


--
-- Name: istat_sezioni; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW istat_sezioni AS
 SELECT st_multi(st_union(c.geom)) AS geom,
    c.ace,
    c.pro_com
   FROM census_areas c
  INNER JOIN cities c2 ON c2.pro_com = c.pro_com
  GROUP BY c.ace, c.pro_com
  WITH NO DATA;


--
-- Name: atlas_sezioni; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW atlas_sezioni AS
 SELECT atlas.gid,
    atlas.code,
    atlas.geom,
    sezione.ace,
    sezione.pro_com
   FROM (istat_sezioni sezione
     JOIN atlas ON (st_intersects(sezione.geom, atlas.geom)))
  WHERE (sezione.pro_com IN ( SELECT cities.pro_com
           FROM cities))
  WITH NO DATA;


--
-- Name: atlas_area_novac; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW atlas_area_novac AS
 SELECT COALESCE(sum(st_area((
        CASE
            WHEN st_coveredby(s.geom, a.geom) THEN s.geom
            ELSE st_multi(st_intersection(a.geom, s.geom))
        END)::geography)), (0)::double precision) AS area,
    s.ace,
    s.pro_com
   FROM (atlas_sezioni a
     JOIN istat_sezioni s ON (((s.ace = a.ace) AND (s.pro_com = a.pro_com))))
  WHERE (a.code = ANY (ARRAY['50000'::text, '14100'::text, '40000'::text, '30000'::text, '31000'::text]))
  GROUP BY s.ace, s.pro_com
  WITH NO DATA;


--
-- Name: atlas_gid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE atlas_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: atlas_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE atlas_gid_seq OWNED BY atlas.gid;


--
-- Name: atlas_railways; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE TABLE railways (
    geom geometry(MultiPolygon,4326),
    city text
);
CREATE INDEX ON railways USING GIST (geom);


create materialized view atlas_railways as
select geom, pro_com
from (
    select a.geom, b.pro_com
    from railways a
    INNER JOIN cities b ON ST_INTERSECTS(a.geom, b.boundary_geom)
) as foo
where not ST_IsEmpty(geom);


--
-- Name: buildings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE buildings (
    gid integer NOT NULL,
    geom geometry(MultiPolygon,4326),
    city text,
    osm_id text
);


--
-- Name: buildings_gid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE buildings_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: buildings_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE buildings_gid_seq OWNED BY buildings.gid;


--
-- Name: buildings_sezioni; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW buildings_sezioni AS
 SELECT (st_dump(st_multi(st_union(buildings.geom)))).geom AS geom,
    sezione.ace,
    sezione.pro_com
   FROM istat_sezioni sezione,
    buildings
  WHERE (st_intersects(sezione.geom, buildings.geom) AND (NOT st_touches(sezione.geom, buildings.geom)))
  GROUP BY sezione.ace, sezione.pro_com
  WITH NO DATA;


--
-- Name: census_areas_gid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE census_areas_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: census_areas_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE census_areas_gid_seq OWNED BY census_areas.gid;


--
-- Name: companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE companies (
    long double precision,
    lat double precision,
    dimension text,
    geom geometry,
    city text
);


CREATE TABLE companies_temp (
    long double precision,
    lat double precision,
    dimension text
);


--
-- Name: foursquare_venues; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE foursquare_venues (
    gridcell integer,
    category text,
    geom geometry(Point,4326),
    name text,
    venueid text,
    city text
);


CREATE TABLE foursquare_venues_temp (
    long double precision,
    lat double precision,
    category character varying(200),
    name character varying(200),
    venueid character varying(200)
);

--
-- Name: istat_indicatori; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE istat_indicatori (
    "CODREG" numeric,
    "REGIONE" character varying,
    "CODPRO" numeric,
    "PROVINCIA" character varying,
    "CODCOM" numeric,
    "COMUNE" character varying,
    "PROCOM" numeric,
    "SEZ2011" numeric,
    "NSEZ" numeric,
    "ACE" numeric,
    "CODLOC" numeric,
    "CODASC" numeric,
    "P1" numeric,
    "P2" numeric,
    "P3" numeric,
    "P4" numeric,
    "P5" numeric,
    "P6" numeric,
    "P7" numeric,
    "P8" numeric,
    "P9" numeric,
    "P10" numeric,
    "P11" numeric,
    "P12" numeric,
    "P13" numeric,
    "P14" numeric,
    "P15" numeric,
    "P16" numeric,
    "P17" numeric,
    "P18" numeric,
    "P19" numeric,
    "P20" numeric,
    "P21" numeric,
    "P22" numeric,
    "P23" numeric,
    "P24" numeric,
    "P25" numeric,
    "P26" numeric,
    "P27" numeric,
    "P28" numeric,
    "P29" numeric,
    "P30" numeric,
    "P31" numeric,
    "P32" numeric,
    "P33" numeric,
    "P34" numeric,
    "P35" numeric,
    "P36" numeric,
    "P37" numeric,
    "P38" numeric,
    "P39" numeric,
    "P40" numeric,
    "P41" numeric,
    "P42" numeric,
    "P43" numeric,
    "P44" numeric,
    "P45" numeric,
    "P46" numeric,
    "P47" numeric,
    "P48" numeric,
    "P49" numeric,
    "P50" numeric,
    "P51" numeric,
    "P52" numeric,
    "P53" numeric,
    "P54" numeric,
    "P55" numeric,
    "P56" numeric,
    "P57" numeric,
    "P58" numeric,
    "P59" numeric,
    "P60" numeric,
    "P61" numeric,
    "P62" numeric,
    "P64" numeric,
    "P65" numeric,
    "P66" numeric,
    "P128" numeric,
    "P129" numeric,
    "P130" numeric,
    "P131" numeric,
    "P132" numeric,
    "P135" numeric,
    "P136" numeric,
    "P137" numeric,
    "P138" numeric,
    "P139" numeric,
    "P140" numeric,
    "ST1" numeric,
    "ST2" numeric,
    "ST3" numeric,
    "ST4" numeric,
    "ST5" numeric,
    "ST6" numeric,
    "ST7" numeric,
    "ST8" numeric,
    "ST9" numeric,
    "ST10" numeric,
    "ST11" numeric,
    "ST12" numeric,
    "ST13" numeric,
    "ST14" numeric,
    "ST15" numeric,
    "A2" numeric,
    "A3" numeric,
    "A5" numeric,
    "A6" numeric,
    "A7" numeric,
    "A44" numeric,
    "A46" numeric,
    "A47" numeric,
    "A48" numeric,
    "PF1" numeric,
    "PF2" numeric,
    "PF3" numeric,
    "PF4" numeric,
    "PF5" numeric,
    "PF6" numeric,
    "PF7" numeric,
    "PF8" numeric,
    "PF9" numeric,
    "E1" numeric,
    "E2" numeric,
    "E3" numeric,
    "E4" numeric,
    "E5" numeric,
    "E6" numeric,
    "E7" numeric,
    "E8" numeric,
    "E9" numeric,
    "E10" numeric,
    "E11" numeric,
    "E12" numeric,
    "E13" numeric,
    "E14" numeric,
    "E15" numeric,
    "E16" numeric,
    "E17" numeric,
    "E18" numeric,
    "E19" numeric,
    "E20" numeric,
    "E21" numeric,
    "E22" numeric,
    "E23" numeric,
    "E24" numeric,
    "E25" numeric,
    "E26" numeric,
    "E27" numeric,
    "E28" numeric,
    "E29" numeric,
    "E30" numeric,
    "E31" numeric
);


--
-- Name: istat_industria; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE istat_industria (
    "TIPO_SOGGETTO" character varying,
    "CODREG" numeric,
    "PROCOM" numeric,
    "NSEZ" numeric,
    "ATECO3" numeric,
    "NUM_UNITA" numeric,
    "ADDETTI" numeric,
    "ALTRI_RETRIB" numeric,
    "VOLONTARI" numeric
);


--
-- Name: parks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE parks (
    osm_id bigint,
    geom geometry(MultiPolygon,4326),
    city text,
    geoarea float
);



--
-- Name: roads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE roads (
    gid integer NOT NULL,
    area character varying(254),
    highway character varying(254),
    junction character varying(254),
    name character varying(254),
    city text,
    geom geometry(LineString,4326)
);


--
-- Name: roads_roundabout; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW roads_roundabout AS
 WITH RECURSIVE inter_agg AS (
         SELECT r.gid,
            (ARRAY[r.gid] || array_agg(r2.gid)) AS arr
           FROM (roads r
             JOIN roads r2 ON ((r.gid <> r2.gid)))
          WHERE (st_intersects(r.geom, r2.geom) AND ((r.junction)::text = 'roundabout'::text) AND ((r2.junction)::text = 'roundabout'::text))
          GROUP BY r.gid
        ), final AS (
         SELECT DISTINCT i.gid,
            i.arr AS inter,
            ARRAY[i.gid] AS ex
           FROM inter_agg i
        UNION
         SELECT f.gid,
            uniq(sort((f.inter || i.arr))) AS uniq,
            uniq(sort((f.ex || ARRAY[i.gid]))) AS uniq
           FROM (final f
             JOIN inter_agg i ON (((f.gid < i.gid) AND (f.inter @> ARRAY[i.gid]) AND ((f.ex @> ARRAY[i.gid]) IS FALSE))))
        )
 SELECT ( SELECT st_union(roads.geom) AS st_union
           FROM roads
          WHERE (roads.gid = ANY (final.inter))) AS geom,
    final.inter
   FROM final
  WHERE (final.inter = final.ex)
  WITH NO DATA;


--
-- Name: roads_2ways; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW roads_2ways AS
 SELECT foo.p,
    foo.road1,
    foo.road2
   FROM ( SELECT DISTINCT (st_dump(st_setsrid(st_intersection(a.geom, b.geom), 4326))).geom AS p,
            a.gid AS road1,
            b.gid AS road2
           FROM (roads a
             JOIN roads b ON ((((a.city)::text = (b.city)::text) AND st_intersects(a.geom, b.geom) AND (a.gid < b.gid) AND ((((a.highway)::text <> (b.highway)::text) AND (a.name IS NULL) AND (b.name IS NULL)) OR ((((a.name)::text <> (b.name)::text) OR (a.name IS NULL) OR (b.name IS NULL)) AND (NOT ((a.name IS NULL) AND (b.name IS NULL))))))))
          WHERE ((NOT (a.gid IN ( SELECT unnest(roads_roundabout.inter) AS unnest
                   FROM roads_roundabout))) AND (NOT (b.gid IN ( SELECT unnest(roads_roundabout.inter) AS unnest
                   FROM roads_roundabout))))) foo
  WHERE ((NOT (EXISTS ( SELECT foo2.inter
           FROM roads_roundabout foo2
          WHERE st_intersects(foo.p, foo2.geom)
         LIMIT 1))) AND (geometrytype(foo.p) = 'POINT'::text))
  WITH NO DATA;


--
-- Name: roads_2ways_sezioni; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW roads_2ways_sezioni AS
 SELECT DISTINCT roads_2ways.p,
    roads_2ways.road1,
    roads_2ways.road2,
    sezione.ace,
    sezione.pro_com
   FROM (roads_2ways
     JOIN istat_sezioni sezione ON (st_within(roads_2ways.p, sezione.geom)))
  WITH NO DATA;


--
-- Name: roads_3ways; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW roads_3ways AS
 SELECT st_setsrid(st_intersection(a.geom, b.p), 4326) AS p,
    b.road1,
    b.road2,
    a.gid AS road3
   FROM (roads a
     JOIN roads_2ways b ON ((st_intersects(a.geom, b.p) AND (a.gid < b.road2) AND (a.gid < b.road1))))
  WHERE (geometrytype(st_intersection(a.geom, b.p)) = 'POINT'::text)
  WITH NO DATA;


--
-- Name: roads_4ways; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW roads_4ways AS
 SELECT DISTINCT st_setsrid(st_intersection(a.geom, b.p), 4326) AS p,
    b.road1,
    b.road2,
    b.road3,
    a.gid AS road4
   FROM (roads a
     JOIN roads_3ways b ON ((st_intersects(a.geom, b.p) AND (a.gid < b.road2) AND (a.gid < b.road1) AND (a.gid < b.road3))))
  WHERE (geometrytype(st_intersection(a.geom, b.p)) = 'POINT'::text)
  WITH NO DATA;


--
-- Name: roads_4ways_sezioni; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW roads_4ways_sezioni AS
 SELECT DISTINCT roads_4ways.p,
    roads_4ways.road1,
    roads_4ways.road2,
    roads_4ways.road3,
    roads_4ways.road4,
    sezione.ace,
    sezione.pro_com
   FROM (roads_4ways
     JOIN istat_sezioni sezione ON (st_within(roads_4ways.p, sezione.geom)))
  WITH NO DATA;


--
-- Name: roads_sezioni; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW roads_sezioni AS
 SELECT roads.gid,
    roads.geom,
    sezione.ace,
    sezione.pro_com,
    roads.name
   FROM istat_sezioni sezione,
    roads
  WHERE st_intersects(sezione.geom, roads.geom)
  WITH NO DATA;


--
-- Name: roads_union; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW roads_union AS
 SELECT st_multi(st_union(roads_sezioni.geom)) AS geom,
    roads_sezioni.ace,
    roads_sezioni.pro_com
   FROM roads_sezioni
  GROUP BY roads_sezioni.ace, roads_sezioni.pro_com
  WITH NO DATA;


--
-- Name: roads_buffered; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW roads_buffered AS
 SELECT st_buffer(roads_union.geom, (0.00005)::double precision) AS geom,
    roads_union.pro_com,
    roads_union.ace
   FROM roads_union
  WITH NO DATA;


--
-- Name: roads_gid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE roads_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roads_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE roads_gid_seq OWNED BY roads.gid;


--
-- Name: roads_roundabout_sezioni; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW roads_roundabout_sezioni AS
 SELECT a.inter,
    a.geom,
    ( SELECT count(b.name) AS count
           FROM roads b
          WHERE (st_intersects(a.geom, b.geom) AND (NOT (b.gid = ANY (a.inter))))) AS num,
    ( SELECT count(DISTINCT b.name) AS count
           FROM roads b
          WHERE (st_intersects(a.geom, b.geom) AND (NOT (b.gid = ANY (a.inter))))) AS numd,
    sezione.ace,
    sezione.pro_com
   FROM (roads_roundabout a
     JOIN istat_sezioni sezione ON (st_intersects(a.geom, sezione.geom)))
  WITH NO DATA;


--
-- Name: temp_atlas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE temp_atlas (
    ogc_fid integer NOT NULL,
    cities character varying(254),
    luz_or_cit character varying(254),
    code character varying(7),
    item character varying(150),
    prod_date character varying(4),
    shape_len numeric(32,10),
    shape_area numeric(32,10),
    wkb_geometry geometry(Geometry,3035)
);


--
-- Name: temp_atlas_ogc_fid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE temp_atlas_ogc_fid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: temp_atlas_ogc_fid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE temp_atlas_ogc_fid_seq OWNED BY temp_atlas.ogc_fid;


--
-- Name: temp_boundaries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE temp_boundaries (
    "URAU_ID" text,
    "URAU_NAME" text,
    "CNTR_CODE" text,
    "URAU_CATG" text,
    "CAPT" text,
    "GRCITY_COD" text,
    "URBC_POPL" bigint,
    "URBC_P_SCR" text,
    "URAU_POPL" bigint,
    "URAU_P_SRC" text,
    "NUTS3_2010" text,
    "NUTS3_2006" text,
    "FUA_CODE" text,
    "PORT" text,
    "AREA_SQK" double precision,
    "URBC_CODE" text,
    geom geometry(MultiPolygon,4326),
    cities character varying(254),
    luz_or_cit character varying(254),
    code character varying(7),
    item character varying(150),
    prod_date character varying(4),
    shape_len numeric(32,10),
    shape_area numeric(32,10)
);


--
-- Name: atlas gid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY atlas ALTER COLUMN gid SET DEFAULT nextval('atlas_gid_seq'::regclass);


--
-- Name: buildings gid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY buildings ALTER COLUMN gid SET DEFAULT nextval('buildings_gid_seq'::regclass);


--
-- Name: census_areas gid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY census_areas ALTER COLUMN gid SET DEFAULT nextval('census_areas_gid_seq'::regclass);


--
-- Name: roads gid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY roads ALTER COLUMN gid SET DEFAULT nextval('roads_gid_seq'::regclass);


--
-- Name: temp_atlas ogc_fid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY temp_atlas ALTER COLUMN ogc_fid SET DEFAULT nextval('temp_atlas_ogc_fid_seq'::regclass);


--
-- Name: census_areas census_areas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY census_areas
    ADD CONSTRAINT census_areas_pkey PRIMARY KEY (sez2011);


--
-- Name: cities cities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cities
    ADD CONSTRAINT cities_pkey PRIMARY KEY (name, pro_com);
ALTER TABLE ONLY cities
    ADD CONSTRAINT cities_ukey UNIQUE (pro_com);
ALTER TABLE ONLY cities
    ADD CONSTRAINT cities_ukey2 UNIQUE (name);

--
-- Name: temp_atlas temp_atlas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY temp_atlas
    ADD CONSTRAINT temp_atlas_pkey PRIMARY KEY (ogc_fid);


ALTER TABLE atlas
    ADD CONSTRAINT fk_atlas FOREIGN KEY (city) REFERENCES cities (name) ON UPDATE RESTRICT ON DELETE CASCADE;

ALTER TABLE buildings
    ADD CONSTRAINT fk_buildings FOREIGN KEY (city) REFERENCES cities (name) ON UPDATE RESTRICT ON DELETE CASCADE;

ALTER TABLE roads
    ADD CONSTRAINT fk_roads FOREIGN KEY (city) REFERENCES cities (name) ON UPDATE RESTRICT ON DELETE CASCADE;

ALTER TABLE companies
    ADD CONSTRAINT fk_companies FOREIGN KEY (city) REFERENCES cities (name) ON UPDATE RESTRICT ON DELETE CASCADE;

ALTER TABLE foursquare_venues
    ADD CONSTRAINT fk_foursquare_venues FOREIGN KEY (city) REFERENCES cities (name) ON UPDATE RESTRICT ON DELETE CASCADE;

ALTER TABLE railways
    ADD CONSTRAINT fk_railways FOREIGN KEY (city) REFERENCES cities (name) ON UPDATE RESTRICT ON DELETE CASCADE;

ALTER TABLE parks
    ADD CONSTRAINT fk_parks FOREIGN KEY (city) REFERENCES cities (name) ON UPDATE RESTRICT ON DELETE CASCADE;

--
-- Name: atlas_area_novac_ace_pro_com_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atlas_area_novac_ace_pro_com_idx ON atlas_area_novac USING btree (ace, pro_com);


--
-- Name: atlas_code_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atlas_code_idx ON atlas USING btree (code);


--
-- Name: atlas_geom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atlas_geom_idx ON atlas USING gist (geom);


--
-- Name: atlas_railways_geom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atlas_railways_geom_idx ON atlas_railways USING gist (geom);


--
-- Name: atlas_railways_pro_com_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atlas_railways_pro_com_idx ON atlas_railways USING btree (pro_com);


--
-- Name: atlas_sezioni_ace_pro_com_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atlas_sezioni_ace_pro_com_idx ON atlas_sezioni USING btree (ace, pro_com);

CREATE INDEX ON atlas_sezioni USING btree (pro_com, ace);
--
-- Name: atlas_sezioni_code_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atlas_sezioni_code_idx ON atlas_sezioni USING hash (code);


--
-- Name: atlas_sezioni_geom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atlas_sezioni_geom_idx ON atlas_sezioni USING gist (geom);


--
-- Name: atlas_sezioni_gid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX atlas_sezioni_gid_idx ON atlas_sezioni USING btree (gid);


create index on buildings USING gist (geom);

--
-- Name: buildings_sezioni_ace_pro_com_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX buildings_sezioni_ace_pro_com_idx ON buildings_sezioni USING btree (ace, pro_com);


--
-- Name: buildings_sezioni_geom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX buildings_sezioni_geom_idx ON buildings_sezioni USING gist (geom);


--
-- Name: census_areas_geom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX census_areas_geom_idx ON census_areas USING gist (geom);


--
-- Name: census_areas_pro_com_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX census_areas_pro_com_idx ON census_areas USING btree (pro_com);


--
-- Name: census_areas_sez2011_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX census_areas_sez2011_idx ON census_areas USING btree (sez2011);


--
-- Name: companies_geom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX companies_geom_idx ON companies USING gist (geom);


--
-- Name: idx_temp_boundaries_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_temp_boundaries_geom ON temp_boundaries USING gist (geom);


--
-- Name: istat_indicatori_ACE_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "istat_indicatori_ACE_idx" ON istat_indicatori USING btree ("ACE");


--
-- Name: istat_indicatori_PROCOM_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "istat_indicatori_PROCOM_idx" ON istat_indicatori USING btree ("PROCOM");


--
-- Name: istat_industria_NSEZ_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "istat_industria_NSEZ_idx" ON istat_industria USING btree ("NSEZ");


--
-- Name: istat_industria_PROCOM_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "istat_industria_PROCOM_idx" ON istat_industria USING btree ("PROCOM");


--
-- Name: istat_sezioni_ace_pro_com_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX istat_sezioni_ace_pro_com_idx ON istat_sezioni USING btree (ace, pro_com);


--
-- Name: istat_sezioni_geom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX istat_sezioni_geom_idx ON istat_sezioni USING gist (geom);


--
-- Name: parks_geom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX parks_geom_idx ON parks USING gist (geom);
CREATE INDEX ON parks (geoarea);


create index on roads (gid);
create index on roads (highway);
create index on roads using gist (geom);
create index on roads (city);
--
-- Name: roads_2ways_p_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_2ways_p_idx ON roads_2ways USING gist (p);


--
-- Name: roads_2ways_p_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_2ways_p_idx1 ON roads_2ways USING gist (p);


--
-- Name: roads_2ways_road1_road2_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_2ways_road1_road2_idx ON roads_2ways USING btree (road1, road2);


--
-- Name: roads_2ways_sezioni_p_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_2ways_sezioni_p_idx ON roads_2ways_sezioni USING gist (p);


--
-- Name: roads_2ways_sezioni_pro_com_ace_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_2ways_sezioni_pro_com_ace_idx ON roads_2ways_sezioni USING btree (pro_com, ace);


--
-- Name: roads_3ways_p_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_3ways_p_idx ON roads_3ways USING gist (p);


--
-- Name: roads_4ways_p_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_4ways_p_idx ON roads_4ways USING gist (p);


--
-- Name: roads_4ways_sezioni_p_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_4ways_sezioni_p_idx ON roads_4ways_sezioni USING gist (p);


--
-- Name: roads_4ways_sezioni_pro_com_ace_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_4ways_sezioni_pro_com_ace_idx ON roads_4ways_sezioni USING btree (pro_com, ace);


--
-- Name: roads_buffered_ace_pro_com_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_buffered_ace_pro_com_idx ON roads_buffered USING btree (ace, pro_com);


--
-- Name: roads_roundabout_geom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_roundabout_geom_idx ON roads_roundabout USING gist (geom);


--
-- Name: roads_roundabout_geom_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_roundabout_geom_idx1 ON roads_roundabout USING gist (geom);


--
-- Name: roads_roundabout_sezioni_pro_com_ace_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_roundabout_sezioni_pro_com_ace_idx ON roads_roundabout_sezioni USING btree (pro_com, ace);


--
-- Name: roads_sezioni_ace_pro_com_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_sezioni_ace_pro_com_idx ON roads_sezioni USING btree (ace, pro_com);


--
-- Name: roads_sezioni_geom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_sezioni_geom_idx ON roads_sezioni USING gist (geom);


--
-- Name: roads_sezioni_gid_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_sezioni_gid_name_idx ON roads_sezioni USING btree (gid, name);


--
-- Name: roads_union_ace_pro_com_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX roads_union_ace_pro_com_idx ON roads_union USING btree (ace, pro_com);


--
-- Name: temp_atlas_wkb_geometry_geom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX temp_atlas_wkb_geometry_geom_idx ON temp_atlas USING gist (wkb_geometry);

create view foursquare_venues_sezioni as 
SELECT distinct v.venueid, category, pro_com, ace 
from foursquare_venues v 
inner join istat_sezioni s on ST_Within(v.geom, s.geom);

create materialized view buildings_union as
select ST_Multi(ST_Union(geom)) as geom, city, buildings.gid from buildings GROUP BY city, gid
  WITH NO DATA;

create index on buildings_union (city);
create index on buildings_union USING GIST (geom);

--
-- PostgreSQL database dump complete
--

