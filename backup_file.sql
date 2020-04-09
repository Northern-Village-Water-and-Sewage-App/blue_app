--
-- PostgreSQL database dump
--

-- Dumped from database version 12.2 (Debian 12.2-2.pgdg100+1)
-- Dumped by pg_dump version 12.2 (Ubuntu 12.2-2.pgdg18.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: add_to_sewage_worklist(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_to_sewage_worklist() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if is_caution_level_sewage_level(new.pk) then
        insert into manager_worklist (time_estimate_fk, resident_fk, tank_type_fk)
        SELECT 6, u.pk, 2
        from sewage_tank_readings tr
                 join residents u on tr.tank_owner_fk = u.pk
        where tr.pk = new.pk
        on conflict do nothing;
    end if;
    return new;
end;
$$;


ALTER FUNCTION public.add_to_sewage_worklist() OWNER TO postgres;

--
-- Name: add_to_water_worklist(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_to_water_worklist() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if is_caution_level_water_level(new.pk) then
        insert into manager_worklist (time_estimate_fk, resident_fk, tank_type_fk)
        SELECT 6, u.pk, 1
        from water_tank_readings tr
                 join residents u on tr.tank_owner_fk = u.pk
        where tr.pk = new.pk
        on conflict do nothing;
    end if;
    return new;
end;
$$;


ALTER FUNCTION public.add_to_water_worklist() OWNER TO postgres;

--
-- Name: does_user_already_exist_in_the_worklist_with_tank_type(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.does_user_already_exist_in_the_worklist_with_tank_type(user_pk integer, tank_type_pk integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
    return exists(select 1 from manager_worklist where resident_fk = user_pk and tank_type_fk = tank_type_pk);
end;
$$;


ALTER FUNCTION public.does_user_already_exist_in_the_worklist_with_tank_type(user_pk integer, tank_type_pk integer) OWNER TO postgres;

--
-- Name: is_caution_level_sewage_level(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_caution_level_sewage_level(reading_pk integer) RETURNS TABLE(is_caution boolean)
    LANGUAGE plpgsql
    AS $$
begin
    return QUERY select (lower(tr.status) = 'warning' or lower(tr.status) = 'critical') from sewage_tank_readings as tr
                          join residents r on tr.tank_owner_fk = r.pk
                 where tr.pk = reading_pk;
end;
$$;


ALTER FUNCTION public.is_caution_level_sewage_level(reading_pk integer) OWNER TO postgres;

--
-- Name: is_caution_level_water_level(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_caution_level_water_level(reading_pk integer) RETURNS TABLE(is_caution boolean)
    LANGUAGE plpgsql
    AS $$
begin
    return QUERY select tr.current_height <= tm.tank_warning_level
                 from water_tank_readings as tr
                          join water_tanks_models tm on tr.tank_model_fk = tm.pk
                 where tr.pk = reading_pk;
end;
$$;


ALTER FUNCTION public.is_caution_level_water_level(reading_pk integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: completed_worklist; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.completed_worklist (
    pk integer NOT NULL,
    resident_fk integer,
    tank_type_fk integer,
    time_at_worklist_added timestamp without time zone,
    "timestamp" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.completed_worklist OWNER TO postgres;

--
-- Name: residents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.residents (
    pk integer NOT NULL,
    username text,
    pin text,
    house_number text,
    water_tank_fk integer,
    sewage_tank_fk integer,
    resident_disabled boolean DEFAULT false
);


ALTER TABLE public.residents OWNER TO postgres;

--
-- Name: tank_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tank_types (
    pk integer NOT NULL,
    tank_type text
);


ALTER TABLE public.tank_types OWNER TO postgres;

--
-- Name: app_completed_worklist; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.app_completed_worklist AS
 SELECT dc.pk,
    r.username,
    r.house_number,
    tt.tank_type,
    dc.time_at_worklist_added,
    dc."timestamp"
   FROM ((public.completed_worklist dc
     JOIN public.residents r ON ((dc.resident_fk = r.pk)))
     JOIN public.tank_types tt ON ((dc.tank_type_fk = tt.pk)));


ALTER TABLE public.app_completed_worklist OWNER TO postgres;

--
-- Name: manager_worklist; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.manager_worklist (
    pk integer NOT NULL,
    resident_fk integer,
    time_estimate_fk integer,
    tank_type_fk integer,
    "timestamp" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    completed boolean DEFAULT false
);


ALTER TABLE public.manager_worklist OWNER TO postgres;

--
-- Name: time_estimates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.time_estimates (
    pk integer NOT NULL,
    estimate text
);


ALTER TABLE public.time_estimates OWNER TO postgres;

--
-- Name: app_get_estimates_for_all_residents; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.app_get_estimates_for_all_residents AS
 SELECT r.username,
    te.estimate,
    tt.tank_type
   FROM (((public.manager_worklist
     JOIN public.residents r ON ((manager_worklist.resident_fk = r.pk)))
     JOIN public.time_estimates te ON ((manager_worklist.time_estimate_fk = te.pk)))
     JOIN public.tank_types tt ON ((manager_worklist.tank_type_fk = tt.pk)));


ALTER TABLE public.app_get_estimates_for_all_residents OWNER TO postgres;

--
-- Name: drivers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.drivers (
    pk integer NOT NULL,
    username text,
    pin text
);


ALTER TABLE public.drivers OWNER TO postgres;

--
-- Name: managers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.managers (
    pk integer NOT NULL,
    username text,
    pin text
);


ALTER TABLE public.managers OWNER TO postgres;

--
-- Name: app_login; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.app_login AS
 SELECT residents.username,
    residents.pin,
    'resident'::text AS user_type
   FROM public.residents
UNION
 SELECT drivers.username,
    drivers.pin,
    'driver'::text AS user_type
   FROM public.drivers
UNION
 SELECT managers.username,
    managers.pin,
    'manager'::text AS user_type
   FROM public.managers;


ALTER TABLE public.app_login OWNER TO postgres;

--
-- Name: app_monthly_stats; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.app_monthly_stats AS
 SELECT this_month_all.this_month_all_avg,
    this_month_all_avg_water.this_month_all_avg_water,
    this_month_all_avg_sewage.this_month_all_avg_sewage,
    this_month_all_calls.this_month_all_calls,
    this_month_all_calls_water.this_month_all_calls_water,
    this_month_all_calls_sewage.this_month_all_calls_sewage,
    previous_all.previous_all_avg,
    previous_all_sewage.previous_all_sewage_avg,
    previous_all_water.previous_all_water_avg,
    previous_all_calls.previous_all_calls,
    previous_all_calls_water.previous_all_calls_water,
    previous_all_calls_sewage.previous_all_calls_sewage
   FROM ( SELECT round(((date_part('epoch'::text, avg(age(completed_worklist."timestamp", completed_worklist.time_at_worklist_added))) / ((60 * 60))::double precision))::numeric, 2) AS this_month_all_avg
           FROM public.completed_worklist
          WHERE ((date_part('month'::text, completed_worklist.time_at_worklist_added) = date_part('month'::text, CURRENT_TIMESTAMP)) AND (date_part('year'::text, completed_worklist.time_at_worklist_added) = date_part('year'::text, CURRENT_TIMESTAMP)))) this_month_all,
    ( SELECT round(((date_part('epoch'::text, avg(age(completed_worklist."timestamp", completed_worklist.time_at_worklist_added))) / ((60 * 60))::double precision))::numeric, 2) AS this_month_all_avg_water
           FROM public.completed_worklist
          WHERE ((date_part('month'::text, completed_worklist.time_at_worklist_added) = date_part('month'::text, CURRENT_TIMESTAMP)) AND (date_part('year'::text, completed_worklist.time_at_worklist_added) = date_part('year'::text, CURRENT_TIMESTAMP)) AND (completed_worklist.tank_type_fk = 1))) this_month_all_avg_water,
    ( SELECT round(((date_part('epoch'::text, avg(age(completed_worklist."timestamp", completed_worklist.time_at_worklist_added))) / ((60 * 60))::double precision))::numeric, 2) AS this_month_all_avg_sewage
           FROM public.completed_worklist
          WHERE ((date_part('month'::text, completed_worklist.time_at_worklist_added) = date_part('month'::text, CURRENT_TIMESTAMP)) AND (date_part('year'::text, completed_worklist.time_at_worklist_added) = date_part('year'::text, CURRENT_TIMESTAMP)) AND (completed_worklist.tank_type_fk = 1))) this_month_all_avg_sewage,
    ( SELECT count(1) AS this_month_all_calls
           FROM public.completed_worklist
          WHERE ((completed_worklist.time_at_worklist_added >= date_trunc('month'::text, (CURRENT_DATE - '2 mons'::interval month))) AND (completed_worklist.time_at_worklist_added < date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone)))) this_month_all_calls,
    ( SELECT count(1) AS this_month_all_calls_water
           FROM public.completed_worklist
          WHERE ((completed_worklist.time_at_worklist_added >= date_trunc('month'::text, (CURRENT_DATE - '2 mons'::interval month))) AND (completed_worklist.time_at_worklist_added < date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone)) AND (completed_worklist.tank_type_fk = 1))) this_month_all_calls_water,
    ( SELECT count(1) AS this_month_all_calls_sewage
           FROM public.completed_worklist
          WHERE ((completed_worklist.time_at_worklist_added >= date_trunc('month'::text, (CURRENT_DATE - '2 mons'::interval month))) AND (completed_worklist.time_at_worklist_added < date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone)) AND (completed_worklist.tank_type_fk = 2))) this_month_all_calls_sewage,
    ( SELECT round(((date_part('epoch'::text, avg(age(completed_worklist."timestamp", completed_worklist.time_at_worklist_added))) / ((60 * 60))::double precision))::numeric, 2) AS previous_all_avg
           FROM public.completed_worklist
          WHERE ((completed_worklist.time_at_worklist_added >= date_trunc('month'::text, (CURRENT_DATE - '2 mons'::interval month))) AND (completed_worklist.time_at_worklist_added < date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone)))) previous_all,
    ( SELECT round(((date_part('epoch'::text, avg(age(completed_worklist."timestamp", completed_worklist.time_at_worklist_added))) / ((60 * 60))::double precision))::numeric, 2) AS previous_all_sewage_avg
           FROM public.completed_worklist
          WHERE ((completed_worklist.time_at_worklist_added >= date_trunc('month'::text, (CURRENT_DATE - '2 mons'::interval month))) AND (completed_worklist.time_at_worklist_added < date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone)) AND (completed_worklist.tank_type_fk = 2))) previous_all_sewage,
    ( SELECT round(((date_part('epoch'::text, avg(age(completed_worklist."timestamp", completed_worklist.time_at_worklist_added))) / ((60 * 60))::double precision))::numeric, 2) AS previous_all_water_avg
           FROM public.completed_worklist
          WHERE ((completed_worklist.time_at_worklist_added >= date_trunc('month'::text, (CURRENT_DATE - '2 mons'::interval month))) AND (completed_worklist.time_at_worklist_added < date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone)) AND (completed_worklist.tank_type_fk = 1))) previous_all_water,
    ( SELECT count(1) AS previous_all_calls
           FROM public.completed_worklist
          WHERE ((completed_worklist.time_at_worklist_added >= date_trunc('month'::text, (CURRENT_DATE - '2 mons'::interval month))) AND (completed_worklist.time_at_worklist_added < date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone)))) previous_all_calls,
    ( SELECT count(1) AS previous_all_calls_water
           FROM public.completed_worklist
          WHERE ((completed_worklist.time_at_worklist_added >= date_trunc('month'::text, (CURRENT_DATE - '2 mons'::interval month))) AND (completed_worklist.time_at_worklist_added < date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone)) AND (completed_worklist.tank_type_fk = 1))) previous_all_calls_water,
    ( SELECT count(1) AS previous_all_calls_sewage
           FROM public.completed_worklist
          WHERE ((completed_worklist.time_at_worklist_added >= date_trunc('month'::text, (CURRENT_DATE - '2 mons'::interval month))) AND (completed_worklist.time_at_worklist_added < date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone)) AND (completed_worklist.tank_type_fk = 2))) previous_all_calls_sewage;


ALTER TABLE public.app_monthly_stats OWNER TO postgres;

--
-- Name: companies; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.companies (
    pk integer NOT NULL,
    company_name text
);


ALTER TABLE public.companies OWNER TO postgres;

--
-- Name: complaint_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.complaint_types (
    pk integer NOT NULL,
    complaint_type text
);


ALTER TABLE public.complaint_types OWNER TO postgres;

--
-- Name: reports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reports (
    pk integer NOT NULL,
    complaint_type_fk integer,
    company_fk integer,
    complaint text,
    "timestamp" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.reports OWNER TO postgres;

--
-- Name: app_reports; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.app_reports AS
 SELECT r.pk,
    ct.complaint_type,
    c.company_name,
    r.complaint
   FROM ((public.reports r
     JOIN public.companies c ON ((r.company_fk = c.pk)))
     JOIN public.complaint_types ct ON ((r.complaint_type_fk = ct.pk)));


ALTER TABLE public.app_reports OWNER TO postgres;

--
-- Name: app_this_month_average; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.app_this_month_average AS
 SELECT (avg((completed_worklist."timestamp" - completed_worklist.time_at_worklist_added)))::text AS avg
   FROM public.completed_worklist
  WHERE ((date_part('month'::text, completed_worklist.time_at_worklist_added) = date_part('month'::text, CURRENT_TIMESTAMP)) AND (date_part('year'::text, completed_worklist.time_at_worklist_added) = date_part('year'::text, CURRENT_TIMESTAMP)));


ALTER TABLE public.app_this_month_average OWNER TO postgres;

--
-- Name: app_worklist; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.app_worklist AS
 SELECT manager_worklist.pk,
    r.username,
    r.house_number,
    tt.tank_type,
    te.estimate,
    to_char(manager_worklist."timestamp", 'DD-Mon-YYYY HH:MM:SSPM'::text) AS "timestamp",
    manager_worklist.completed
   FROM (((public.manager_worklist
     JOIN public.residents r ON ((manager_worklist.resident_fk = r.pk)))
     JOIN public.time_estimates te ON ((manager_worklist.time_estimate_fk = te.pk)))
     JOIN public.tank_types tt ON ((manager_worklist.tank_type_fk = tt.pk)));


ALTER TABLE public.app_worklist OWNER TO postgres;

--
-- Name: companies_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.companies_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.companies_pk_seq OWNER TO postgres;

--
-- Name: companies_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.companies_pk_seq OWNED BY public.companies.pk;


--
-- Name: complaint_types_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.complaint_types_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.complaint_types_pk_seq OWNER TO postgres;

--
-- Name: complaint_types_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.complaint_types_pk_seq OWNED BY public.complaint_types.pk;


--
-- Name: delivery_completed_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.delivery_completed_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.delivery_completed_pk_seq OWNER TO postgres;

--
-- Name: delivery_completed_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.delivery_completed_pk_seq OWNED BY public.completed_worklist.pk;


--
-- Name: drivers_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.drivers_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.drivers_pk_seq OWNER TO postgres;

--
-- Name: drivers_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.drivers_pk_seq OWNED BY public.drivers.pk;


--
-- Name: manager_worklist_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.manager_worklist_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.manager_worklist_pk_seq OWNER TO postgres;

--
-- Name: manager_worklist_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.manager_worklist_pk_seq OWNED BY public.manager_worklist.pk;


--
-- Name: managers_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.managers_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.managers_pk_seq OWNER TO postgres;

--
-- Name: managers_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.managers_pk_seq OWNED BY public.managers.pk;


--
-- Name: message; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.message (
    pk integer NOT NULL,
    messages text,
    "timestamp" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.message OWNER TO postgres;

--
-- Name: message_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.message_pk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.message_pk_seq OWNER TO postgres;

--
-- Name: message_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.message_pk_seq OWNED BY public.message.pk;


--
-- Name: reports_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.reports_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.reports_pk_seq OWNER TO postgres;

--
-- Name: reports_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.reports_pk_seq OWNED BY public.reports.pk;


--
-- Name: residents_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.residents_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.residents_pk_seq OWNER TO postgres;

--
-- Name: residents_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.residents_pk_seq OWNED BY public.residents.pk;


--
-- Name: sewage_tank_readings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sewage_tank_readings (
    pk integer NOT NULL,
    status text,
    "timestamp" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    tank_owner_fk integer,
    tank_model_fk integer
);


ALTER TABLE public.sewage_tank_readings OWNER TO postgres;

--
-- Name: sewage_tank_readings_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sewage_tank_readings_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sewage_tank_readings_pk_seq OWNER TO postgres;

--
-- Name: sewage_tank_readings_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sewage_tank_readings_pk_seq OWNED BY public.sewage_tank_readings.pk;


--
-- Name: sewage_tanks_models; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sewage_tanks_models (
    pk integer NOT NULL,
    tank_model text,
    tank_height double precision,
    tank_width double precision,
    tank_length double precision,
    tank_warning_level double precision,
    tank_critical_level double precision
);


ALTER TABLE public.sewage_tanks_models OWNER TO postgres;

--
-- Name: sewage_tanks_models_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sewage_tanks_models_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sewage_tanks_models_pk_seq OWNER TO postgres;

--
-- Name: sewage_tanks_models_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sewage_tanks_models_pk_seq OWNED BY public.sewage_tanks_models.pk;


--
-- Name: water_tank_readings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.water_tank_readings (
    pk integer NOT NULL,
    current_height double precision,
    "timestamp" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    tank_owner_fk integer,
    tank_model_fk integer
);


ALTER TABLE public.water_tank_readings OWNER TO postgres;

--
-- Name: tank_readings_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tank_readings_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tank_readings_pk_seq OWNER TO postgres;

--
-- Name: tank_readings_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tank_readings_pk_seq OWNED BY public.water_tank_readings.pk;


--
-- Name: tank_types_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tank_types_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tank_types_pk_seq OWNER TO postgres;

--
-- Name: tank_types_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tank_types_pk_seq OWNED BY public.tank_types.pk;


--
-- Name: time_estimates_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.time_estimates_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.time_estimates_pk_seq OWNER TO postgres;

--
-- Name: time_estimates_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.time_estimates_pk_seq OWNED BY public.time_estimates.pk;


--
-- Name: water_tanks_models; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.water_tanks_models (
    pk integer NOT NULL,
    tank_height double precision,
    tank_width double precision,
    tank_length double precision,
    tank_warning_level double precision,
    tank_critical_level double precision,
    tank_model text
);


ALTER TABLE public.water_tanks_models OWNER TO postgres;

--
-- Name: water_tanks_model_pk_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.water_tanks_model_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.water_tanks_model_pk_seq OWNER TO postgres;

--
-- Name: water_tanks_model_pk_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.water_tanks_model_pk_seq OWNED BY public.water_tanks_models.pk;


--
-- Name: companies pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.companies ALTER COLUMN pk SET DEFAULT nextval('public.companies_pk_seq'::regclass);


--
-- Name: complaint_types pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_types ALTER COLUMN pk SET DEFAULT nextval('public.complaint_types_pk_seq'::regclass);


--
-- Name: completed_worklist pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.completed_worklist ALTER COLUMN pk SET DEFAULT nextval('public.delivery_completed_pk_seq'::regclass);


--
-- Name: drivers pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers ALTER COLUMN pk SET DEFAULT nextval('public.drivers_pk_seq'::regclass);


--
-- Name: manager_worklist pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.manager_worklist ALTER COLUMN pk SET DEFAULT nextval('public.manager_worklist_pk_seq'::regclass);


--
-- Name: managers pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.managers ALTER COLUMN pk SET DEFAULT nextval('public.managers_pk_seq'::regclass);


--
-- Name: message pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.message ALTER COLUMN pk SET DEFAULT nextval('public.message_pk_seq'::regclass);


--
-- Name: reports pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reports ALTER COLUMN pk SET DEFAULT nextval('public.reports_pk_seq'::regclass);


--
-- Name: residents pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.residents ALTER COLUMN pk SET DEFAULT nextval('public.residents_pk_seq'::regclass);


--
-- Name: sewage_tank_readings pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sewage_tank_readings ALTER COLUMN pk SET DEFAULT nextval('public.sewage_tank_readings_pk_seq'::regclass);


--
-- Name: sewage_tanks_models pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sewage_tanks_models ALTER COLUMN pk SET DEFAULT nextval('public.sewage_tanks_models_pk_seq'::regclass);


--
-- Name: tank_types pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tank_types ALTER COLUMN pk SET DEFAULT nextval('public.tank_types_pk_seq'::regclass);


--
-- Name: time_estimates pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.time_estimates ALTER COLUMN pk SET DEFAULT nextval('public.time_estimates_pk_seq'::regclass);


--
-- Name: water_tank_readings pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.water_tank_readings ALTER COLUMN pk SET DEFAULT nextval('public.tank_readings_pk_seq'::regclass);


--
-- Name: water_tanks_models pk; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.water_tanks_models ALTER COLUMN pk SET DEFAULT nextval('public.water_tanks_model_pk_seq'::regclass);


--
-- Data for Name: companies; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.companies (pk, company_name) FROM stdin;
1	KHMB
3	KRG
4	Makivik
2	KSB
\.


--
-- Data for Name: complaint_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.complaint_types (pk, complaint_type) FROM stdin;
1	Complaint
3	Malfunctioning Lights
2	Broken Lights
4	No Need for Call
\.


--
-- Data for Name: completed_worklist; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.completed_worklist (pk, resident_fk, tank_type_fk, time_at_worklist_added, "timestamp") FROM stdin;
3	1	2	2020-03-05 21:02:44	2020-04-05 23:03:06
4	1	2	2020-03-05 21:02:44	2020-04-05 23:03:06
5	1	2	2020-03-05 21:02:44	2020-04-05 23:03:06
2	1	2	2020-04-05 14:58:19.54	2020-04-05 17:42:54.583091
1	1	2	2020-04-05 14:58:19.54	2020-04-05 17:35:02.577679
7	1	1	2020-03-05 19:02:44	2020-04-05 23:03:06
6	1	1	2020-04-05 13:58:19.54	2020-04-05 17:35:02.577679
8	14	1	2020-04-06 15:01:40.707674	2020-04-06 19:14:13.593002
9	1	1	2020-04-05 17:06:19.146264	2020-04-06 19:18:58.239189
10	1	1	2020-04-06 19:54:10.624147	2020-04-07 16:24:19.489692
11	1	2	2020-04-06 19:54:08.055373	2020-04-08 00:18:17.231615
12	14	2	2020-04-06 15:05:00.322334	2020-04-08 00:19:41.135429
13	16	1	2020-04-06 15:03:51.699031	2020-04-08 00:20:01.243715
14	16	2	2020-04-08 00:30:26.752916	2020-04-08 00:52:37.979328
15	15	2	2020-04-08 00:28:16.083359	2020-04-08 00:58:49.529822
16	16	1	2020-04-08 00:52:51.985748	2020-04-08 00:59:00.466228
17	1	2	2020-04-08 00:36:34.790528	2020-04-08 05:23:30.334375
18	1	1	2020-04-08 00:23:27.251696	2020-04-08 19:37:47.839523
19	15	1	2020-04-09 00:16:46.724322	2020-04-09 00:21:39.413767
20	1	1	2020-04-09 00:09:18.779284	2020-04-09 00:42:44.236375
21	1	2	2020-04-08 19:33:50.669425	2020-04-09 00:42:49.203045
\.


--
-- Data for Name: drivers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.drivers (pk, username, pin) FROM stdin;
11	Taha	666
12	Pelton	789
\.


--
-- Data for Name: manager_worklist; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.manager_worklist (pk, resident_fk, time_estimate_fk, tank_type_fk, "timestamp", completed) FROM stdin;
145	15	6	1	2020-04-09 00:35:45.838059	f
149	1	4	2	2020-04-09 00:43:09.250957	f
148	1	3	1	2020-04-09 00:43:09.18472	f
\.


--
-- Data for Name: managers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.managers (pk, username, pin) FROM stdin;
5	Zohaib	123
\.


--
-- Data for Name: message; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.message (pk, messages, "timestamp") FROM stdin;
4	Random Message	2020-04-04 21:27:26.416964
5	Hello There	2020-04-04 21:37:23.936721
6	UIMA Zebedee	2020-04-08 00:36:39.8209
7	Bonsoir Zebedee	2020-04-08 00:42:58.60391
8	2 water broken	2020-04-08 20:45:02.636323
\.


--
-- Data for Name: reports; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.reports (pk, complaint_type_fk, company_fk, complaint, "timestamp") FROM stdin;
5	3	4	Both lights go on at row houses at the bottom of the hill	2020-04-08 00:54:07
2	1	1	Tanks difficult to access Behind house 23	2020-04-04 21:28:29.349709
3	2	2	Broken water high at house 34	2020-04-04 21:37:05.462448
4	3	3	Lights at police house need to be replaced	2020-04-08 00:54:07.1275
\.


--
-- Data for Name: residents; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.residents (pk, username, pin, house_number, water_tank_fk, sewage_tank_fk, resident_disabled) FROM stdin;
15	Jordan	687	220	1	1	f
1	Zebedee	555	H-123	1	1	f
17	Ali	605	456	1	1	f
14	Siasi	928	19	1	1	f
16	Mina	414	313	1	1	f
\.


--
-- Data for Name: sewage_tank_readings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sewage_tank_readings (pk, status, "timestamp", tank_owner_fk, tank_model_fk) FROM stdin;
39	warning	2020-04-05 00:29:05.281484	1	1
40	warning	2020-04-05 01:26:59.044472	1	1
41	warning	2020-04-05 01:27:13.094604	1	1
42	warning	2020-04-05 01:27:21.586976	1	1
43	warning	2020-04-05 01:27:49.917601	1	1
44	warning	2020-04-05 01:28:04.152481	1	1
45	warning	2020-04-05 01:28:25.898618	1	1
46	warning	2020-04-05 01:30:38.305772	1	1
47	warning	2020-04-05 01:30:49.794615	1	1
48	warning	2020-04-05 01:44:53.927237	1	1
49	warning	2020-04-05 01:45:00.539472	1	1
50	2	2020-04-05 03:07:49.282815	1	1
51	WARNING	2020-04-05 03:08:13.240092	1	1
52	CRITICAL	2020-04-05 05:54:25.607108	1	1
53	WARNING	2020-04-05 05:56:32.664959	1	1
54	CRITICAL	2020-04-05 05:58:55.309854	1	1
55	WARNING	2020-04-05 05:59:26.088904	1	1
56	WARNING	2020-04-05 05:59:28.153804	1	1
57	OK	2020-04-05 05:59:44.334058	1	1
58	OK	2020-04-05 05:59:46.531814	1	1
59	warning	2020-04-05 15:00:43.690642	1	1
60	warning	2020-04-05 15:01:46.208536	1	1
62	warning	2020-04-05 16:58:19.540723	1	1
63	warning	2020-04-05 16:58:26.157192	1	1
64	OK	2020-04-06 19:53:51.894543	1	1
65	WARNING	2020-04-06 19:54:08.055373	1	1
66	2	2020-04-08 00:28:41.790821	1	1
67	2	2020-04-08 00:29:29.044123	1	1
68	2	2020-04-08 00:29:59.336682	16	1
69	CRITICAL	2020-04-08 00:30:26.752916	16	1
70	WARNING	2020-04-08 00:36:34.790528	1	1
71	WARNING	2020-04-08 00:42:15.717709	1	1
72	CRITICAL	2020-04-08 00:43:04.478931	1	1
73	CRITICAL	2020-04-08 00:46:25.301378	1	1
74	WARNING	2020-04-08 00:46:43.975359	1	1
75	OK	2020-04-08 00:46:54.085737	1	1
76	CRITICAL	2020-04-08 00:59:06.476232	1	1
77	OK	2020-04-08 01:00:20.558485	1	1
78	WARNING	2020-04-08 01:00:48.313337	1	1
79	CRITICAL	2020-04-08 01:02:33.437598	1	1
80	2	2020-04-08 21:59:39.70881	1	1
81	OK	2020-04-08 21:59:44.135412	1	1
82	2	2020-04-08 22:31:47.735214	1	1
83	CRITICAL	2020-04-08 22:31:58.172047	1	1
84	OK	2020-04-09 00:39:21.437995	1	1
\.


--
-- Data for Name: sewage_tanks_models; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sewage_tanks_models (pk, tank_model, tank_height, tank_width, tank_length, tank_warning_level, tank_critical_level) FROM stdin;
1	Cylindrical	100	100	100	50	75
\.


--
-- Data for Name: tank_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tank_types (pk, tank_type) FROM stdin;
2	Sewage
1	Water
\.


--
-- Data for Name: time_estimates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.time_estimates (pk, estimate) FROM stdin;
2	On the way
3	Before the Break
4	Today
5	Tomorrow
6	Not Decided
\.


--
-- Data for Name: water_tank_readings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.water_tank_readings (pk, current_height, "timestamp", tank_owner_fk, tank_model_fk) FROM stdin;
103	80	2020-04-04 22:22:34.589644	1	1
106	80	2020-04-04 22:23:41.95561	1	1
109	50	2020-04-04 22:27:00.70146	1	1
110	69	2020-04-04 22:27:42.496148	1	1
111	0	2020-04-04 22:28:23.392708	1	1
112	55	2020-04-04 23:39:24.791769	1	1
113	2	2020-04-05 03:09:08.577022	1	1
114	2	2020-04-05 05:54:30.259368	1	1
115	2	2020-04-05 05:54:32.339234	1	1
116	60	2020-04-05 17:04:52.311406	1	1
117	10	2020-04-05 17:05:01.145593	1	1
118	10	2020-04-05 17:05:52.182798	1	1
119	10	2020-04-05 17:06:19.146264	1	1
120	10	2020-04-05 17:06:24.534402	1	1
121	40	2020-04-05 18:14:51.993678	1	1
122	40	2020-04-06 19:54:10.624147	1	1
123	99	2020-04-06 19:54:17.780711	1	1
124	1	2020-04-08 00:23:27.251696	1	1
125	25	2020-04-08 00:33:04.824279	1	1
126	69	2020-04-08 00:34:26.863949	1	1
127	100	2020-04-08 00:34:54.139182	1	1
128	1000	2020-04-08 00:50:22.743412	1	1
129	0	2020-04-08 21:32:52.197947	1	1
130	0	2020-04-08 21:41:16.731007	1	1
131	0	2020-04-08 21:44:33.978859	1	1
132	22	2020-04-08 21:54:21.441204	1	1
133	23	2020-04-08 22:02:13.479111	1	1
134	23	2020-04-08 22:10:00.578262	1	1
135	22	2020-04-08 22:17:03.823064	1	1
136	23	2020-04-08 22:24:07.158205	1	1
137	22	2020-04-08 22:31:10.449108	1	1
138	100	2020-04-09 00:07:21.724507	1	1
139	99	2020-04-09 00:09:18.779284	1	1
140	1	2020-04-09 00:38:57.133932	1	1
\.


--
-- Data for Name: water_tanks_models; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.water_tanks_models (pk, tank_height, tank_width, tank_length, tank_warning_level, tank_critical_level, tank_model) FROM stdin;
1	100	50	50	75	50	Cylindrical
2	100	100	100	75	50	Box
3	100	50	50	75	50	Horizontal Cylinder
\.


--
-- Name: companies_pk_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.companies_pk_seq', 8, true);


--
-- Name: complaint_types_pk_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.complaint_types_pk_seq', 8, true);


--
-- Name: delivery_completed_pk_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.delivery_completed_pk_seq', 21, true);


--
-- Name: drivers_pk_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.drivers_pk_seq', 13, true);


--
-- Name: manager_worklist_pk_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.manager_worklist_pk_seq', 150, true);


--
-- Name: managers_pk_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.managers_pk_seq', 6, true);


--
-- Name: message_pk_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.message_pk_seq', 8, true);


--
-- Name: reports_pk_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.reports_pk_seq', 5, true);


--
-- Name: residents_pk_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.residents_pk_seq', 17, true);


--
-- Name: sewage_tank_readings_pk_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sewage_tank_readings_pk_seq', 84, true);


--
-- Name: sewage_tanks_models_pk_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sewage_tanks_models_pk_seq', 2, true);


--
-- Name: tank_readings_pk_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tank_readings_pk_seq', 140, true);


--
-- Name: tank_types_pk_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tank_types_pk_seq', 1, false);


--
-- Name: time_estimates_pk_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.time_estimates_pk_seq', 5, true);


--
-- Name: water_tanks_model_pk_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.water_tanks_model_pk_seq', 4, true);


--
-- Name: companies companies_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pk PRIMARY KEY (pk);


--
-- Name: complaint_types complaint_types_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.complaint_types
    ADD CONSTRAINT complaint_types_pk PRIMARY KEY (pk);


--
-- Name: completed_worklist delivery_completed_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.completed_worklist
    ADD CONSTRAINT delivery_completed_pk PRIMARY KEY (pk);


--
-- Name: drivers drivers_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_pk PRIMARY KEY (pk);


--
-- Name: manager_worklist manager_worklist_resident_fk_tank_type_fk_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.manager_worklist
    ADD CONSTRAINT manager_worklist_resident_fk_tank_type_fk_key UNIQUE (resident_fk, tank_type_fk);


--
-- Name: managers managers_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.managers
    ADD CONSTRAINT managers_pk PRIMARY KEY (pk);


--
-- Name: message message_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_pk PRIMARY KEY (pk);


--
-- Name: manager_worklist pk_manager_worklist; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.manager_worklist
    ADD CONSTRAINT pk_manager_worklist PRIMARY KEY (pk);


--
-- Name: water_tank_readings pk_tank_readings; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.water_tank_readings
    ADD CONSTRAINT pk_tank_readings PRIMARY KEY (pk);


--
-- Name: tank_types pk_tank_types; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tank_types
    ADD CONSTRAINT pk_tank_types PRIMARY KEY (pk);


--
-- Name: time_estimates pk_time_estimates; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.time_estimates
    ADD CONSTRAINT pk_time_estimates PRIMARY KEY (pk);


--
-- Name: reports reports_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pk PRIMARY KEY (pk);


--
-- Name: residents residents_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.residents
    ADD CONSTRAINT residents_pk PRIMARY KEY (pk);


--
-- Name: sewage_tank_readings sewage_tank_readings_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sewage_tank_readings
    ADD CONSTRAINT sewage_tank_readings_pk PRIMARY KEY (pk);


--
-- Name: sewage_tanks_models sewage_tanks_models_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sewage_tanks_models
    ADD CONSTRAINT sewage_tanks_models_pk PRIMARY KEY (pk);


--
-- Name: water_tanks_models water_tanks_model_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.water_tanks_models
    ADD CONSTRAINT water_tanks_model_pk PRIMARY KEY (pk);


--
-- Name: companies_pk_uindex; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX companies_pk_uindex ON public.companies USING btree (pk);


--
-- Name: complaint_types_pk_uindex; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX complaint_types_pk_uindex ON public.complaint_types USING btree (pk);


--
-- Name: delivery_completed_pk_uindex; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX delivery_completed_pk_uindex ON public.completed_worklist USING btree (pk);


--
-- Name: drivers_new_username_uindex; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX drivers_new_username_uindex ON public.drivers USING btree (username);


--
-- Name: drivers_pk_uindex; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX drivers_pk_uindex ON public.drivers USING btree (pk);


--
-- Name: managers_new_username_uindex; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX managers_new_username_uindex ON public.managers USING btree (username);


--
-- Name: managers_pk_uindex; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX managers_pk_uindex ON public.managers USING btree (pk);


--
-- Name: reports_pk_uindex; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX reports_pk_uindex ON public.reports USING btree (pk);


--
-- Name: residents_new_username_uindex; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX residents_new_username_uindex ON public.residents USING btree (username);


--
-- Name: residents_pk_uindex; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX residents_pk_uindex ON public.residents USING btree (pk);


--
-- Name: sewage_tank_readings_pk_uindex; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX sewage_tank_readings_pk_uindex ON public.sewage_tank_readings USING btree (pk);


--
-- Name: sewage_tanks_models_pk_uindex; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX sewage_tanks_models_pk_uindex ON public.sewage_tanks_models USING btree (pk);


--
-- Name: water_tanks_model_pk_uindex; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX water_tanks_model_pk_uindex ON public.water_tanks_models USING btree (pk);


--
-- Name: sewage_tank_readings add_to_sewage_worklist; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER add_to_sewage_worklist AFTER INSERT ON public.sewage_tank_readings FOR EACH ROW EXECUTE FUNCTION public.add_to_sewage_worklist();


--
-- Name: water_tank_readings add_to_water_worklist; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER add_to_water_worklist AFTER INSERT ON public.water_tank_readings FOR EACH ROW EXECUTE FUNCTION public.add_to_water_worklist();


--
-- Name: completed_worklist delivery_completed_residents_pk_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.completed_worklist
    ADD CONSTRAINT delivery_completed_residents_pk_fk FOREIGN KEY (resident_fk) REFERENCES public.residents(pk);


--
-- Name: completed_worklist delivery_completed_tank_types_pk_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.completed_worklist
    ADD CONSTRAINT delivery_completed_tank_types_pk_fk FOREIGN KEY (tank_type_fk) REFERENCES public.tank_types(pk);


--
-- Name: manager_worklist fk_manager_worklist_resident_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.manager_worklist
    ADD CONSTRAINT fk_manager_worklist_resident_fk FOREIGN KEY (resident_fk) REFERENCES public.residents(pk);


--
-- Name: manager_worklist fk_manager_worklist_time_estimate_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.manager_worklist
    ADD CONSTRAINT fk_manager_worklist_time_estimate_fk FOREIGN KEY (time_estimate_fk) REFERENCES public.time_estimates(pk);


--
-- Name: water_tank_readings fk_tank_readings_tank_models; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.water_tank_readings
    ADD CONSTRAINT fk_tank_readings_tank_models FOREIGN KEY (tank_model_fk) REFERENCES public.water_tanks_models(pk);


--
-- Name: water_tank_readings fk_tank_readings_tank_owner_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.water_tank_readings
    ADD CONSTRAINT fk_tank_readings_tank_owner_fk FOREIGN KEY (tank_owner_fk) REFERENCES public.residents(pk);


--
-- Name: manager_worklist manager_worklist_tank_types_pk_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.manager_worklist
    ADD CONSTRAINT manager_worklist_tank_types_pk_fk FOREIGN KEY (tank_type_fk) REFERENCES public.tank_types(pk);


--
-- Name: reports reports_companies_pk_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_companies_pk_fk FOREIGN KEY (company_fk) REFERENCES public.companies(pk);


--
-- Name: reports reports_complaint_types_pk_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_complaint_types_pk_fk FOREIGN KEY (complaint_type_fk) REFERENCES public.complaint_types(pk);


--
-- Name: residents residents_sewage_tanks_models_pk_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.residents
    ADD CONSTRAINT residents_sewage_tanks_models_pk_fk FOREIGN KEY (sewage_tank_fk) REFERENCES public.sewage_tanks_models(pk);


--
-- Name: residents residents_water_tanks_model_pk_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.residents
    ADD CONSTRAINT residents_water_tanks_model_pk_fk FOREIGN KEY (water_tank_fk) REFERENCES public.water_tanks_models(pk);


--
-- Name: sewage_tank_readings sewage_tank_readings_residents_pk_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sewage_tank_readings
    ADD CONSTRAINT sewage_tank_readings_residents_pk_fk FOREIGN KEY (tank_owner_fk) REFERENCES public.residents(pk);


--
-- Name: sewage_tank_readings sewage_tank_readings_sewage_tanks_models_pk_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sewage_tank_readings
    ADD CONSTRAINT sewage_tank_readings_sewage_tanks_models_pk_fk FOREIGN KEY (tank_model_fk) REFERENCES public.sewage_tanks_models(pk);


--
-- PostgreSQL database dump complete
--

