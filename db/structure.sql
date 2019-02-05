--
-- PostgreSQL database dump
--

-- Dumped from database version 10.6 (Ubuntu 10.6-1.pgdg18.04+1)
-- Dumped by pg_dump version 10.6 (Ubuntu 10.6-1.pgdg18.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
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
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


--
-- Name: ec_chargecentroidfromguards(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ec_chargecentroidfromguards(chargeid integer) RETURNS text
    LANGUAGE sql
    AS $$
SELECT ST_AsText(st_centroid(st_union(location))) as centroid
FROM guards
where charge_id=chargeid
$$;


--
-- Name: ec_entries_update_gps_raws_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ec_entries_update_gps_raws_count() RETURNS void
    LANGUAGE sql
    AS $$
UPDATE entries e 
SET gps_raws_count=c.count 
FROM (SELECT entry_id,count(*) as count from gps_raws group by entry_id) c
WHERE e.id=c.entry_id
$$;


--
-- Name: ec_entrylegcreateline(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ec_entrylegcreateline(entrylegid integer) RETURNS void
    LANGUAGE sql
    AS $$

UPDATE entry_legs SET leg_line=ln.line
FROM
(
SELECT ST_MakeLine(c.location) as line FROM gps_cleans c
WHERE 	c.id >=(SELECT gps_clean_id FROM checkins i INNER JOIN entry_legs el ON i.id=el.checkin1_id WHERE el.id=entrylegid) AND
	c.id <=(SELECT gps_clean_id FROM checkins i INNER JOIN entry_legs el ON i.id=el.checkin2_id WHERE el.id=entrylegid)
) ln
WHERE
entry_legs.id=entrylegid;

UPDATE entry_legs SET leg_line_proj=ST_Transform(leg_line,3857) WHERE id=entrylegid;

UPDATE entry_legs SET distance_m=ST_Length(leg_line_proj) WHERE id=entrylegid;

$$;


--
-- Name: ec_gps_raws_import(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ec_gps_raws_import(charge_id integer) RETURNS void
    LANGUAGE sql
    AS $$
INSERT INTO gps_raws (entry_id,gps_timestamp,location,source_ref)
SELECT
	e.id,
	i.timedate,
	ST_SetSRID(ST_MakePoint(i.lon,i.lat),4326),
	'GEOTAB'
FROM
	entries e 
	INNER JOIN charges c ON e.charge_id=c.id
	INNER JOIN teams t on e.team_id=t.id
	inner join import_2016 i on i.teamid=e.car_no
WHERE
	c.id=charge_id 
$$;


--
-- Name: ec_gpscleanscreateline(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ec_gpscleanscreateline(entryid integer) RETURNS void
    LANGUAGE sql
    AS $$
UPDATE 
	entry_geoms SET clean_line=ln.line
FROM
	(
	SELECT 
		pnts.entry_id,ST_MakeLine(pnts.location) as line
	FROM 
		(SELECT entry_id,location FROM gps_cleans WHERE entry_id=entryid ORDER BY id) AS pnts 
	GROUP BY 
		pnts.entry_id
	) as ln
WHERE
	entry_geoms.entry_id=entryid;

UPDATE entry_geoms SET clean_line_kml=trim(trailing '</coordinates></LineString>' from trim(leading '<LineString><coordinates>' from ST_AsKML(clean_line,7))) WHERE entry_id=entryid;
UPDATE entry_geoms SET clean_line_json=ST_AsGeoJSON(clean_line,7) WHERE entry_id=entryid;

$$;


--
-- Name: ec_gpscleansupdatecalcs(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ec_gpscleansupdatecalcs(entryid integer) RETURNS void
    LANGUAGE sql
    AS $$


UPDATE gps_cleans SET
	elapsed_s=calcs.elapsed_s,
	distance_m=calcs.dist_m,
	speed_kmh=calcs.speed_kmh,
	azimuth_deg=calcs.azimuth_deg
FROM
(
SELECT
	cur.id as id,
	CAST(EXTRACT(EPOCH FROM cur.gps_timestamp)-EXTRACT(EPOCH FROM prev.gps_timestamp) AS INTEGER) as elapsed_s,
	ST_Distance(prev.location_prj,cur.location_prj) as dist_m,
	ST_Distance(prev.location_prj,cur.location_prj)/(EXTRACT(EPOCH FROM cur.gps_timestamp)-EXTRACT(EPOCH FROM prev.gps_timestamp))/1000*60*60 as speed_kmh,
	DEGREES(ST_Azimuth(prev.location_prj,cur.location_prj)) as azimuth_deg
FROM
	gps_cleans prev
	INNER JOIN gps_cleans cur ON prev.entry_id=cur.entry_id AND prev.id=cur.id-1
	INNER JOIN entries e on cur.entry_id=e.id
WHERE
	cur.entry_id=entryid
) calcs
WHERE
	gps_cleans.id=calcs.id;

UPDATE entry_geoms SET cleans_count=c.cnt 
FROM ( SELECT entry_id,COUNT(*) as cnt FROM gps_cleans WHERE entry_id=entryid GROUP BY entry_id ) c
WHERE entry_geoms.entry_id=c.entry_id;

UPDATE entry_geoms SET stops_count=c.cnt 
FROM ( SELECT entry_id,COUNT(*) as cnt FROM gps_stops WHERE entry_id=entryid GROUP BY entry_id ) c
WHERE entry_geoms.entry_id=c.entry_id;


$$;


--
-- Name: ec_gpsrawscreateline(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ec_gpsrawscreateline(entryid integer) RETURNS void
    LANGUAGE sql
    AS $$
UPDATE 
	entry_geoms SET raw_line=ln.line
FROM
	(
	SELECT 
		pnts.entry_id,ST_MakeLine(pnts.location) as line
	FROM 
		(SELECT entry_id,location FROM gps_raws WHERE entry_id=entryid and speed_kmh>0 ORDER BY id) AS pnts 
	GROUP BY 
		pnts.entry_id
	) as ln
WHERE
	entry_geoms.entry_id=entryid;

UPDATE entry_geoms SET raw_line_kml=trim(trailing '</coordinates></LineString>' from trim(leading '<LineString><coordinates>' from ST_AsKML(raw_line,7))) WHERE entry_id=entryid;
UPDATE entry_geoms SET raw_line_json=ST_AsGeoJSON(raw_line,7) WHERE entry_id=entryid;

$$;


--
-- Name: ec_gpsrawsupdatecalcs(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ec_gpsrawsupdatecalcs(entryid integer) RETURNS void
    LANGUAGE sql
    AS $$


UPDATE gps_raws SET
	elapsed_s=calcs.elapsed_s,
	distance_m=calcs.dist_m,
	speed_kmh=calcs.speed_kmh,
	azimuth_deg=calcs.azimuth_deg
FROM
(
SELECT
	cur.id as id,
	CAST(EXTRACT(EPOCH FROM cur.gps_timestamp)-EXTRACT(EPOCH FROM prev.gps_timestamp) AS INTEGER) as elapsed_s,
	ST_Distance(prev.location_prj,cur.location_prj) as dist_m,
	ST_Distance(prev.location_prj,cur.location_prj)/(EXTRACT(EPOCH FROM cur.gps_timestamp)-EXTRACT(EPOCH FROM prev.gps_timestamp))/1000*60*60 as speed_kmh,
	DEGREES(ST_Azimuth(prev.location_prj,cur.location_prj)) as azimuth_deg
FROM
	gps_raws prev
	INNER JOIN gps_raws cur ON prev.entry_id=cur.entry_id AND prev.id=cur.id-1
	INNER JOIN entries e on cur.entry_id=e.id
WHERE
	cur.entry_id=entryid
) calcs
WHERE
	gps_raws.id=calcs.id;

UPDATE entry_geoms SET raws_count=c.cnt 
FROM ( SELECT entry_id,COUNT(*) as cnt FROM gps_raws WHERE entry_id=entryid GROUP BY entry_id ) c
WHERE entry_geoms.entry_id=c.entry_id;

UPDATE entry_geoms SET raws_from=c.frm
FROM ( SELECT entry_id,MIN(gps_timestamp) as frm FROM gps_raws WHERE entry_id=entryid GROUP BY entry_id ) c
WHERE entry_geoms.entry_id=c.entry_id;

UPDATE entry_geoms SET raws_to=c.tot
FROM ( SELECT entry_id,MAX(gps_timestamp) as tot FROM gps_raws WHERE entry_id=entryid GROUP BY entry_id ) c
WHERE entry_geoms.entry_id=c.entry_id;

$$;


--
-- Name: ec_guardcheckinforentry(integer, integer, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ec_guardcheckinforentry(entryid integer, guardid integer, from_time timestamp without time zone, to_time timestamp without time zone) RETURNS TABLE(guard_id integer, gps_clean_id integer, gps_timestamp timestamp without time zone, dist_m double precision)
    LANGUAGE sql ROWS 1
    AS $$

SELECT
	g.id,
	gps.id,
	gps.gps_timestamp,
	ST_Distance(gps.location_prj,ST_Transform(g.location,3857))
FROM
	gps_cleans gps
	INNER JOIN guards g ON ST_DWithin(gps.location_prj,ST_Transform(g.location,3857),g.radius_m)	
WHERE	
	gps.entry_id=entryid and g.id=guardid and
	gps.gps_timestamp>=from_time and
	gps.gps_timestamp<=to_time
ORDER BY
	ST_Distance(gps.location_prj,ST_Transform(g.location,3857))
LIMIT 1


$$;


--
-- Name: ec_guardsdistance(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ec_guardsdistance(guard1id integer, guard2id integer) RETURNS double precision
    LANGUAGE sql
    AS $$

SELECT ST_Distance(ST_Transform((SELECT location FROM guards WHERE id=guard1id),3857),ST_Transform((SELECT location FROM guards WHERE id=guard2id),3857))

$$;


--
-- Name: ec_linesforleg(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ec_linesforleg(legid integer) RETURNS TABLE(json text, entry_id integer)
    LANGUAGE sql
    AS $$
SELECT 
	ST_AsGEOJSON(el.leg_line),
	el.entry_id as entry_id
FROM
	legs l
	INNER JOIN entry_legs el ON l.id=el.leg_id
WHERE
	l.id=legid
	
$$;


--
-- Name: ec_pointswithinguardforentry(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ec_pointswithinguardforentry(entryid integer) RETURNS TABLE(guard_id integer, gps_clean_id integer, gps_timestamp timestamp without time zone, dist_m double precision)
    LANGUAGE sql
    AS $$

SELECT
	g.id,
	gps.id,
	gps.gps_timestamp,
	ST_Distance(gps.location_prj,ST_Transform(g.location,3857))
FROM
	gps_cleans gps
	INNER JOIN guards g ON ST_DWithin(gps.location_prj,ST_Transform(g.location,3857),g.radius_m)
	INNER JOIN sponsors gs on g.sponsor_id=gs.id
	INNER JOIN entries e ON e.id=gps.entry_id and g.charge_id=e.charge_id
WHERE	
	gps.entry_id=entryid
ORDER BY
	gps.gps_timestamp

$$;


--
-- Name: ec_rawlinesnearguard(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ec_rawlinesnearguard(guardid integer) RETURNS TABLE(json text, entry_id integer)
    LANGUAGE sql
    AS $$
SELECT 
	ST_AsGEOJSON(ST_Intersection((SELECT ST_Buffer(location,0.001, 'quad_segs=2') FROM guards WHERE Id=guardid),e.raw_line)),
	en.id as entry_id
FROM
	entry_geoms e
	INNER JOIN entries en on e.entry_id=en.id
	INNER JOIN guards g on en.charge_id=g.charge_id
WHERE
	g.id=guardid and e.raw_line IS NOT NULL
	
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: beneficiaries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.beneficiaries (
    id integer NOT NULL,
    name character varying,
    short_name character varying,
    geography character varying,
    description character varying,
    logo_file_name character varying,
    logo_content_type character varying,
    logo_file_size integer,
    logo_updated_at timestamp without time zone,
    website character varying,
    facebook character varying,
    email_admin character varying,
    email_public character varying,
    geography_description character varying,
    grant_description_default character varying
);


--
-- Name: beneficeries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.beneficeries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: beneficeries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.beneficeries_id_seq OWNED BY public.beneficiaries.id;


--
-- Name: campaigns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campaigns (
    id integer NOT NULL,
    mailchimp_id character varying,
    web_id character varying,
    send_time timestamp without time zone,
    archive_url character varying,
    long_archive_url character varying,
    subject_line character varying,
    title character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: campaigns_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.campaigns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: campaigns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.campaigns_id_seq OWNED BY public.campaigns.id;


--
-- Name: cars; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cars (
    id integer NOT NULL,
    name character varying,
    make_old character varying,
    car_model character varying,
    colour character varying,
    year integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    make_id integer
);


--
-- Name: cars_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cars_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cars_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cars_id_seq OWNED BY public.cars.id;


--
-- Name: charge_help_points; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.charge_help_points (
    id integer NOT NULL,
    name character varying,
    charge_id integer,
    location public.geometry(Point,4326)
);


--
-- Name: charge_help_points_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.charge_help_points_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: charge_help_points_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.charge_help_points_id_seq OWNED BY public.charge_help_points.id;


--
-- Name: charge_sponsors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.charge_sponsors (
    id integer NOT NULL,
    charge_id integer,
    sponsor_id integer,
    type_ref character varying(10),
    sponsorship_type_ref character varying(10),
    sponsorship_description character varying
);


--
-- Name: charge_sponsors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.charge_sponsors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: charge_sponsors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.charge_sponsors_id_seq OWNED BY public.charge_sponsors.id;


--
-- Name: charges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.charges (
    id integer NOT NULL,
    name character varying NOT NULL,
    location character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    map_scale integer,
    map_center public.geometry(Point,4326),
    entries_count integer DEFAULT 0 NOT NULL,
    guards_count integer DEFAULT 0 NOT NULL,
    guards_located_count integer DEFAULT 0 NOT NULL,
    start_time time without time zone,
    end_time time without time zone,
    charge_date date NOT NULL,
    ref character varying(25) NOT NULL,
    gauntlet_multiplier integer NOT NULL,
    exchange_rate double precision,
    m_per_kwacha double precision,
    map_file_name character varying,
    map_content_type character varying,
    map_file_size integer,
    map_updated_at timestamp without time zone,
    spirit_entry_id integer,
    spirit_name character varying,
    spirit_description character varying,
    best_guard_id integer,
    shafted_entry_id integer,
    tsetse1_id integer,
    tsetse2_id integer,
    shafted_description character varying,
    elevation_max integer,
    elevation_min integer,
    has_result boolean
);


--
-- Name: charges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.charges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: charges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.charges_id_seq OWNED BY public.charges.id;


--
-- Name: checkins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checkins (
    id integer NOT NULL,
    entry_id integer NOT NULL,
    guard_id integer NOT NULL,
    gps_clean_id integer,
    checkin_number integer NOT NULL,
    checkin_timestamp timestamp without time zone NOT NULL,
    is_duplicate boolean
);


--
-- Name: checkins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.checkins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: checkins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.checkins_id_seq OWNED BY public.checkins.id;


--
-- Name: entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entries (
    id integer NOT NULL,
    car_no integer,
    raised_kwacha integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    charge_id integer,
    team_id integer,
    car_id integer,
    is_ladies boolean,
    is_international boolean,
    is_newcomer boolean,
    is_bikes boolean,
    start_guard_id integer,
    state_ref character varying(10),
    state_messages character varying(255)[],
    result_guards integer DEFAULT 0,
    dist_nongauntlet integer,
    dist_gauntlet integer,
    dist_penalty_gauntlet integer,
    dist_penalty_nongauntlet integer,
    dist_withpentalty_gauntlet integer,
    dist_withpentalty_nongauntlet integer,
    dist_multiplied_gauntlet integer,
    dist_real integer,
    dist_competition integer,
    dist_tsetse1 integer,
    dist_tsetse2 integer,
    result_gauntlet_guards integer DEFAULT 0,
    position_distance integer,
    position_net_distance integer,
    position_gauntlet integer,
    position_tsetse1 integer,
    position_tsetse2 integer,
    dist_net integer,
    dist_best integer,
    result_state_ref character varying(10),
    result_state_messages character varying(255)[],
    late_finish_min integer,
    position_raised integer,
    name character varying,
    captain character varying,
    members character varying,
    position_ladies integer,
    position_newcomer integer,
    position_international integer,
    position_bikes integer,
    result_description character varying,
    position_net_bikes integer,
    entry_no integer
);


--
-- Name: entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entries_id_seq OWNED BY public.entries.id;


--
-- Name: entry_geoms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entry_geoms (
    id integer NOT NULL,
    entry_id integer NOT NULL,
    raw_line public.geometry(LineString,4326),
    clean_line public.geometry(LineString,4326),
    raw_line_kml text,
    clean_line_kml text,
    raw_line_json text,
    clean_line_json text,
    raws_count integer,
    cleans_count integer,
    stops_count integer,
    raws_from timestamp without time zone,
    raws_to timestamp without time zone,
    result_line public.geometry(LineString,4326)
);


--
-- Name: entry_geoms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entry_geoms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entry_geoms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entry_geoms_id_seq OWNED BY public.entry_geoms.id;


--
-- Name: entry_legs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entry_legs (
    id integer NOT NULL,
    entry_id integer NOT NULL,
    leg_id integer NOT NULL,
    direction_forward boolean,
    distance_m integer,
    elapsed_s integer,
    checkin1_id integer NOT NULL,
    checkin2_id integer NOT NULL,
    leg_line public.geometry(LineString,4326),
    leg_line_proj public.geometry(LineString,3857),
    leg_number integer,
    start_time timestamp without time zone,
    elevation_min integer,
    elevation_max integer,
    total_ascent integer,
    total_descent integer
);


--
-- Name: entry_legs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entry_legs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entry_legs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entry_legs_id_seq OWNED BY public.entry_legs.id;


--
-- Name: photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.photos (
    id integer NOT NULL,
    photo_file_name character varying,
    photo_content_type character varying,
    photo_file_size integer,
    photo_updated_at timestamp without time zone,
    photoable_id integer,
    photoable_type character varying,
    aspect double precision,
    is_car boolean,
    faces integer[],
    faces_count integer DEFAULT 0,
    views integer
);


--
-- Name: entry_photos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entry_photos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entry_photos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entry_photos_id_seq OWNED BY public.photos.id;


--
-- Name: gps_cleans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gps_cleans (
    id integer NOT NULL,
    entry_id integer NOT NULL,
    gps_timestamp timestamp without time zone NOT NULL,
    location public.geometry(Point,4326),
    location_prj public.geometry(Point,3857),
    stop_id integer,
    distance_m double precision,
    speed_kmh double precision,
    azimuth_deg double precision,
    elapsed_s integer,
    elevation integer,
    leg_distance_m integer,
    entry_leg_id integer
);


--
-- Name: gps_cleans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gps_cleans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gps_cleans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gps_cleans_id_seq OWNED BY public.gps_cleans.id;


--
-- Name: gps_historic; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gps_historic (
    id integer NOT NULL,
    lat double precision,
    lon double precision,
    gps_timestamp timestamp with time zone,
    teamname character varying(50),
    charge integer
);


--
-- Name: gps_historic_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gps_historic_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gps_historic_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gps_historic_id_seq OWNED BY public.gps_historic.id;


--
-- Name: gps_raws; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gps_raws (
    id integer NOT NULL,
    entry_id integer NOT NULL,
    gps_timestamp timestamp without time zone NOT NULL,
    location public.geometry(Point,4326),
    location_prj public.geometry(Point,3857),
    distance_m double precision,
    speed_kmh double precision,
    azimuth_deg double precision,
    elapsed_s integer
);


--
-- Name: gps_raws2_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gps_raws2_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gps_raws2_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gps_raws2_id_seq OWNED BY public.gps_raws.id;


--
-- Name: gps_stops; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gps_stops (
    id integer NOT NULL,
    entry_id integer NOT NULL,
    start_timestamp timestamp without time zone NOT NULL,
    end_timestamp timestamp without time zone NOT NULL,
    location public.geometry(Point,4326),
    location_prj public.geometry(Point,3857),
    elapsed_s integer
);


--
-- Name: gps_stops_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gps_stops_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gps_stops_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gps_stops_id_seq OWNED BY public.gps_stops.id;


--
-- Name: grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grants (
    id integer NOT NULL,
    charge_id integer,
    beneficiary_id integer,
    grant_kwacha integer,
    description character varying
);


--
-- Name: grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.grants_id_seq OWNED BY public.grants.id;


--
-- Name: sponsors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sponsors (
    id integer NOT NULL,
    name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    short_name character varying,
    website character varying,
    facebook character varying,
    logo_file_name character varying,
    logo_content_type character varying,
    logo_file_size integer,
    logo_updated_at timestamp without time zone,
    email_admin character varying,
    email_public character varying,
    ref character varying(25)
);


--
-- Name: guard_sponsors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.guard_sponsors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: guard_sponsors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.guard_sponsors_id_seq OWNED BY public.sponsors.id;


--
-- Name: guards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guards (
    id integer NOT NULL,
    is_gauntlet boolean,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    sponsor_id integer NOT NULL,
    charge_id integer NOT NULL,
    radius_m integer,
    late_start_time time without time zone,
    location public.geometry(Point,4326),
    elevation integer
);


--
-- Name: guards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.guards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: guards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.guards_id_seq OWNED BY public.guards.id;


--
-- Name: legs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legs (
    id integer NOT NULL,
    guard1_id integer NOT NULL,
    guard2_id integer NOT NULL,
    distance_m integer,
    charge_id integer,
    is_gauntlet boolean DEFAULT false,
    is_tsetse boolean DEFAULT false
);


--
-- Name: legs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.legs_id_seq OWNED BY public.legs.id;


--
-- Name: makes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.makes (
    id integer NOT NULL,
    name character varying,
    ref character varying
);


--
-- Name: makes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.makes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: makes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.makes_id_seq OWNED BY public.makes.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teams (
    id integer NOT NULL,
    name character varying,
    captain character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    badge_file_name character varying,
    badge_content_type character varying,
    badge_file_size integer,
    badge_updated_at timestamp without time zone,
    ref character varying(25),
    tier integer DEFAULT 0 NOT NULL,
    prefix character varying,
    paypal_button character varying,
    facebook character varying,
    email character varying
);


--
-- Name: teams_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.teams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: teams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.teams_id_seq OWNED BY public.teams.id;


--
-- Name: beneficiaries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.beneficiaries ALTER COLUMN id SET DEFAULT nextval('public.beneficeries_id_seq'::regclass);


--
-- Name: campaigns id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaigns ALTER COLUMN id SET DEFAULT nextval('public.campaigns_id_seq'::regclass);


--
-- Name: cars id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cars ALTER COLUMN id SET DEFAULT nextval('public.cars_id_seq'::regclass);


--
-- Name: charge_help_points id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_help_points ALTER COLUMN id SET DEFAULT nextval('public.charge_help_points_id_seq'::regclass);


--
-- Name: charge_sponsors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_sponsors ALTER COLUMN id SET DEFAULT nextval('public.charge_sponsors_id_seq'::regclass);


--
-- Name: charges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges ALTER COLUMN id SET DEFAULT nextval('public.charges_id_seq'::regclass);


--
-- Name: checkins id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkins ALTER COLUMN id SET DEFAULT nextval('public.checkins_id_seq'::regclass);


--
-- Name: entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries ALTER COLUMN id SET DEFAULT nextval('public.entries_id_seq'::regclass);


--
-- Name: entry_geoms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entry_geoms ALTER COLUMN id SET DEFAULT nextval('public.entry_geoms_id_seq'::regclass);


--
-- Name: entry_legs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entry_legs ALTER COLUMN id SET DEFAULT nextval('public.entry_legs_id_seq'::regclass);


--
-- Name: gps_cleans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gps_cleans ALTER COLUMN id SET DEFAULT nextval('public.gps_cleans_id_seq'::regclass);


--
-- Name: gps_historic id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gps_historic ALTER COLUMN id SET DEFAULT nextval('public.gps_historic_id_seq'::regclass);


--
-- Name: gps_raws id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gps_raws ALTER COLUMN id SET DEFAULT nextval('public.gps_raws2_id_seq'::regclass);


--
-- Name: gps_stops id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gps_stops ALTER COLUMN id SET DEFAULT nextval('public.gps_stops_id_seq'::regclass);


--
-- Name: grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grants ALTER COLUMN id SET DEFAULT nextval('public.grants_id_seq'::regclass);


--
-- Name: guards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guards ALTER COLUMN id SET DEFAULT nextval('public.guards_id_seq'::regclass);


--
-- Name: legs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legs ALTER COLUMN id SET DEFAULT nextval('public.legs_id_seq'::regclass);


--
-- Name: makes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makes ALTER COLUMN id SET DEFAULT nextval('public.makes_id_seq'::regclass);


--
-- Name: photos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photos ALTER COLUMN id SET DEFAULT nextval('public.entry_photos_id_seq'::regclass);


--
-- Name: sponsors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsors ALTER COLUMN id SET DEFAULT nextval('public.guard_sponsors_id_seq'::regclass);


--
-- Name: teams id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams ALTER COLUMN id SET DEFAULT nextval('public.teams_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: campaigns campaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_pkey PRIMARY KEY (id);


--
-- Name: cars cars_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cars
    ADD CONSTRAINT cars_pkey PRIMARY KEY (id);


--
-- Name: charge_help_points charge_help_points_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_help_points
    ADD CONSTRAINT charge_help_points_pkey PRIMARY KEY (id);


--
-- Name: charges charges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges
    ADD CONSTRAINT charges_pkey PRIMARY KEY (id);


--
-- Name: entries entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT entries_pkey PRIMARY KEY (id);


--
-- Name: entry_geoms entry_geoms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entry_geoms
    ADD CONSTRAINT entry_geoms_pkey PRIMARY KEY (id);


--
-- Name: sponsors guard_sponsors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponsors
    ADD CONSTRAINT guard_sponsors_pkey PRIMARY KEY (id);


--
-- Name: guards guards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guards
    ADD CONSTRAINT guards_pkey PRIMARY KEY (id);


--
-- Name: beneficiaries pk_beneficeries; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.beneficiaries
    ADD CONSTRAINT pk_beneficeries PRIMARY KEY (id);


--
-- Name: charge_sponsors pk_charge_sponsors; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_sponsors
    ADD CONSTRAINT pk_charge_sponsors PRIMARY KEY (id);


--
-- Name: checkins pk_checkins; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkins
    ADD CONSTRAINT pk_checkins PRIMARY KEY (id);


--
-- Name: entry_legs pk_entry_legs; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entry_legs
    ADD CONSTRAINT pk_entry_legs PRIMARY KEY (id);


--
-- Name: photos pk_entry_photos; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photos
    ADD CONSTRAINT pk_entry_photos PRIMARY KEY (id);


--
-- Name: gps_cleans pk_gps_cleans; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gps_cleans
    ADD CONSTRAINT pk_gps_cleans PRIMARY KEY (id);


--
-- Name: gps_historic pk_gps_histroic; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gps_historic
    ADD CONSTRAINT pk_gps_histroic PRIMARY KEY (id);


--
-- Name: gps_raws pk_gps_raws2; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gps_raws
    ADD CONSTRAINT pk_gps_raws2 PRIMARY KEY (id);


--
-- Name: gps_stops pk_gps_stops; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gps_stops
    ADD CONSTRAINT pk_gps_stops PRIMARY KEY (id);


--
-- Name: grants pk_grants; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grants
    ADD CONSTRAINT pk_grants PRIMARY KEY (id);


--
-- Name: legs pk_legs; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legs
    ADD CONSTRAINT pk_legs PRIMARY KEY (id);


--
-- Name: makes pk_makes; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makes
    ADD CONSTRAINT pk_makes PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: entry_geoms unq_entry_geoms_entry_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entry_geoms
    ADD CONSTRAINT unq_entry_geoms_entry_id UNIQUE (entry_id);


--
-- Name: index_charge_help_points_on_charge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charge_help_points_on_charge_id ON public.charge_help_points USING btree (charge_id);


--
-- Name: index_entries_on_car_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_car_id ON public.entries USING btree (car_id);


--
-- Name: index_entries_on_charge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_charge_id ON public.entries USING btree (charge_id);


--
-- Name: index_entries_on_start_guard_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_start_guard_id ON public.entries USING btree (start_guard_id);


--
-- Name: index_entries_on_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_team_id ON public.entries USING btree (team_id);


--
-- Name: index_guards_on_charge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guards_on_charge_id ON public.guards USING btree (charge_id);


--
-- Name: index_guards_on_guard_sponsor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guards_on_guard_sponsor_id ON public.guards USING btree (sponsor_id);


--
-- Name: indx_gps_cleans_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX indx_gps_cleans_entry_id ON public.gps_cleans USING btree (entry_id);


--
-- Name: indx_gps_raws_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX indx_gps_raws_entry_id ON public.gps_raws USING btree (entry_id);


--
-- Name: cars fk_cars_makes; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cars
    ADD CONSTRAINT fk_cars_makes FOREIGN KEY (make_id) REFERENCES public.makes(id);


--
-- Name: charges fk_charge_bestguard; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges
    ADD CONSTRAINT fk_charge_bestguard FOREIGN KEY (best_guard_id) REFERENCES public.guards(id);


--
-- Name: charge_sponsors fk_charge_sponsors_charge; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_sponsors
    ADD CONSTRAINT fk_charge_sponsors_charge FOREIGN KEY (charge_id) REFERENCES public.charges(id);


--
-- Name: charge_sponsors fk_charge_sponsors_sponsors; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_sponsors
    ADD CONSTRAINT fk_charge_sponsors_sponsors FOREIGN KEY (sponsor_id) REFERENCES public.sponsors(id);


--
-- Name: charges fk_charges_shaftedentry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges
    ADD CONSTRAINT fk_charges_shaftedentry FOREIGN KEY (shafted_entry_id) REFERENCES public.entries(id);


--
-- Name: charges fk_charges_tsetse1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges
    ADD CONSTRAINT fk_charges_tsetse1 FOREIGN KEY (tsetse1_id) REFERENCES public.legs(id);


--
-- Name: charges fk_charges_tsetse2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges
    ADD CONSTRAINT fk_charges_tsetse2 FOREIGN KEY (tsetse2_id) REFERENCES public.legs(id);


--
-- Name: checkins fk_checkin_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkins
    ADD CONSTRAINT fk_checkin_entry FOREIGN KEY (entry_id) REFERENCES public.entries(id);


--
-- Name: checkins fk_checkin_gps_cleans; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkins
    ADD CONSTRAINT fk_checkin_gps_cleans FOREIGN KEY (gps_clean_id) REFERENCES public.gps_cleans(id);


--
-- Name: checkins fk_checkin_guard; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkins
    ADD CONSTRAINT fk_checkin_guard FOREIGN KEY (guard_id) REFERENCES public.guards(id);


--
-- Name: entry_geoms fk_entry_geoms_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entry_geoms
    ADD CONSTRAINT fk_entry_geoms_entry FOREIGN KEY (entry_id) REFERENCES public.entries(id);


--
-- Name: entry_legs fk_entry_leg_checkin1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entry_legs
    ADD CONSTRAINT fk_entry_leg_checkin1 FOREIGN KEY (checkin1_id) REFERENCES public.checkins(id);


--
-- Name: entry_legs fk_entry_leg_checkin2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entry_legs
    ADD CONSTRAINT fk_entry_leg_checkin2 FOREIGN KEY (checkin2_id) REFERENCES public.checkins(id);


--
-- Name: entry_legs fk_entry_legs_entry; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entry_legs
    ADD CONSTRAINT fk_entry_legs_entry FOREIGN KEY (entry_id) REFERENCES public.entries(id);


--
-- Name: entry_legs fk_entry_legs_leg; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entry_legs
    ADD CONSTRAINT fk_entry_legs_leg FOREIGN KEY (leg_id) REFERENCES public.legs(id);


--
-- Name: gps_cleans fk_gps_cleans_entries; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gps_cleans
    ADD CONSTRAINT fk_gps_cleans_entries FOREIGN KEY (entry_id) REFERENCES public.entries(id);


--
-- Name: gps_cleans fk_gps_cleans_entry_leg; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gps_cleans
    ADD CONSTRAINT fk_gps_cleans_entry_leg FOREIGN KEY (entry_leg_id) REFERENCES public.entry_legs(id);


--
-- Name: gps_cleans fk_gps_cleans_gps_stops; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gps_cleans
    ADD CONSTRAINT fk_gps_cleans_gps_stops FOREIGN KEY (stop_id) REFERENCES public.gps_stops(id);


--
-- Name: gps_raws fk_gps_raws_entries2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gps_raws
    ADD CONSTRAINT fk_gps_raws_entries2 FOREIGN KEY (entry_id) REFERENCES public.entries(id);


--
-- Name: gps_stops fk_gps_stops_entries; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gps_stops
    ADD CONSTRAINT fk_gps_stops_entries FOREIGN KEY (entry_id) REFERENCES public.entries(id);


--
-- Name: grants fk_grants_beneficeries; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grants
    ADD CONSTRAINT fk_grants_beneficeries FOREIGN KEY (beneficiary_id) REFERENCES public.beneficiaries(id);


--
-- Name: grants fk_grants_charges; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grants
    ADD CONSTRAINT fk_grants_charges FOREIGN KEY (charge_id) REFERENCES public.charges(id);


--
-- Name: legs fk_legs_charge; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legs
    ADD CONSTRAINT fk_legs_charge FOREIGN KEY (charge_id) REFERENCES public.charges(id);


--
-- Name: legs fk_legs_guards1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legs
    ADD CONSTRAINT fk_legs_guards1 FOREIGN KEY (guard1_id) REFERENCES public.guards(id);


--
-- Name: legs fk_legs_guards2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legs
    ADD CONSTRAINT fk_legs_guards2 FOREIGN KEY (guard2_id) REFERENCES public.guards(id);


--
-- Name: guards fk_rails_41012a5173; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guards
    ADD CONSTRAINT fk_rails_41012a5173 FOREIGN KEY (sponsor_id) REFERENCES public.sponsors(id);


--
-- Name: entries fk_rails_8069469873; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT fk_rails_8069469873 FOREIGN KEY (car_id) REFERENCES public.cars(id);


--
-- Name: guards fk_rails_867149c68d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guards
    ADD CONSTRAINT fk_rails_867149c68d FOREIGN KEY (charge_id) REFERENCES public.charges(id);


--
-- Name: entries fk_rails_9e5fcf2529; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT fk_rails_9e5fcf2529 FOREIGN KEY (charge_id) REFERENCES public.charges(id);


--
-- Name: charge_help_points fk_rails_c72e667370; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charge_help_points
    ADD CONSTRAINT fk_rails_c72e667370 FOREIGN KEY (charge_id) REFERENCES public.charges(id);


--
-- Name: entries fk_rails_e278410c5f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT fk_rails_e278410c5f FOREIGN KEY (start_guard_id) REFERENCES public.guards(id);


--
-- Name: entries fk_rails_f0fbcbbb17; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT fk_rails_f0fbcbbb17 FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20161003193839'),
('20161003195041'),
('20161004045039'),
('20161004045228'),
('20161004045434'),
('20161004045616'),
('20161004045817'),
('20161004184528'),
('20161004185135'),
('20161005063810'),
('20161005064452'),
('20161010052049'),
('20161010053023'),
('20161010053314'),
('20161010114846'),
('20161011222354'),
('20161012080600'),
('20161106200834'),
('20161106201642'),
('20170416185534'),
('20170420143537'),
('20170420143647'),
('20170421071722'),
('20170421101324'),
('20170421101356'),
('20170421101651'),
('20170421134410'),
('20170422065538'),
('20170422065712'),
('20170422130447'),
('20170423182021'),
('20170506094432'),
('20181006033021'),
('20181006033825'),
('20181006074216'),
('20181006075344');


