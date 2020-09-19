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
-- Name: que_validate_tags(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.que_validate_tags(tags_array jsonb) RETURNS boolean
    LANGUAGE sql
    AS $$
  SELECT bool_and(
    jsonb_typeof(value) = 'string'
    AND
    char_length(value::text) <= 100
  )
  FROM jsonb_array_elements(tags_array)
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: que_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.que_jobs (
    priority smallint DEFAULT 100 NOT NULL,
    run_at timestamp with time zone DEFAULT now() NOT NULL,
    id bigint NOT NULL,
    job_class text NOT NULL,
    error_count integer DEFAULT 0 NOT NULL,
    last_error_message text,
    queue text DEFAULT 'default'::text NOT NULL,
    last_error_backtrace text,
    finished_at timestamp with time zone,
    expired_at timestamp with time zone,
    args jsonb DEFAULT '[]'::jsonb NOT NULL,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT error_length CHECK (((char_length(last_error_message) <= 500) AND (char_length(last_error_backtrace) <= 10000))),
    CONSTRAINT job_class_length CHECK ((char_length(
CASE job_class
    WHEN 'ActiveJob::QueueAdapters::QueAdapter::JobWrapper'::text THEN ((args -> 0) ->> 'job_class'::text)
    ELSE job_class
END) <= 200)),
    CONSTRAINT queue_length CHECK ((char_length(queue) <= 100)),
    CONSTRAINT valid_args CHECK ((jsonb_typeof(args) = 'array'::text)),
    CONSTRAINT valid_data CHECK (((jsonb_typeof(data) = 'object'::text) AND ((NOT (data ? 'tags'::text)) OR ((jsonb_typeof((data -> 'tags'::text)) = 'array'::text) AND (jsonb_array_length((data -> 'tags'::text)) <= 5) AND public.que_validate_tags((data -> 'tags'::text))))))
)
WITH (fillfactor='90');


--
-- Name: TABLE que_jobs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.que_jobs IS '4';


--
-- Name: que_determine_job_state(public.que_jobs); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.que_determine_job_state(job public.que_jobs) RETURNS text
    LANGUAGE sql
    AS $$
  SELECT
    CASE
    WHEN job.expired_at  IS NOT NULL    THEN 'expired'
    WHEN job.finished_at IS NOT NULL    THEN 'finished'
    WHEN job.error_count > 0            THEN 'errored'
    WHEN job.run_at > CURRENT_TIMESTAMP THEN 'scheduled'
    ELSE                                     'ready'
    END
$$;


--
-- Name: que_job_notify(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.que_job_notify() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  DECLARE
    locker_pid integer;
    sort_key json;
  BEGIN
    -- Don't do anything if the job is scheduled for a future time.
    IF NEW.run_at IS NOT NULL AND NEW.run_at > now() THEN
      RETURN null;
    END IF;

    -- Pick a locker to notify of the job's insertion, weighted by their number
    -- of workers. Should bounce pseudorandomly between lockers on each
    -- invocation, hence the md5-ordering, but still touch each one equally,
    -- hence the modulo using the job_id.
    SELECT pid
    INTO locker_pid
    FROM (
      SELECT *, last_value(row_number) OVER () + 1 AS count
      FROM (
        SELECT *, row_number() OVER () - 1 AS row_number
        FROM (
          SELECT *
          FROM public.que_lockers ql, generate_series(1, ql.worker_count) AS id
          WHERE listening AND queues @> ARRAY[NEW.queue]
          ORDER BY md5(pid::text || id::text)
        ) t1
      ) t2
    ) t3
    WHERE NEW.id % count = row_number;

    IF locker_pid IS NOT NULL THEN
      -- There's a size limit to what can be broadcast via LISTEN/NOTIFY, so
      -- rather than throw errors when someone enqueues a big job, just
      -- broadcast the most pertinent information, and let the locker query for
      -- the record after it's taken the lock. The worker will have to hit the
      -- DB in order to make sure the job is still visible anyway.
      SELECT row_to_json(t)
      INTO sort_key
      FROM (
        SELECT
          'job_available' AS message_type,
          NEW.queue       AS queue,
          NEW.priority    AS priority,
          NEW.id          AS id,
          -- Make sure we output timestamps as UTC ISO 8601
          to_char(NEW.run_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS run_at
      ) t;

      PERFORM pg_notify('que_listener_' || locker_pid::text, sort_key::text);
    END IF;

    RETURN null;
  END
$$;


--
-- Name: que_state_notify(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.que_state_notify() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  DECLARE
    row record;
    message json;
    previous_state text;
    current_state text;
  BEGIN
    IF TG_OP = 'INSERT' THEN
      previous_state := 'nonexistent';
      current_state  := public.que_determine_job_state(NEW);
      row            := NEW;
    ELSIF TG_OP = 'DELETE' THEN
      previous_state := public.que_determine_job_state(OLD);
      current_state  := 'nonexistent';
      row            := OLD;
    ELSIF TG_OP = 'UPDATE' THEN
      previous_state := public.que_determine_job_state(OLD);
      current_state  := public.que_determine_job_state(NEW);

      -- If the state didn't change, short-circuit.
      IF previous_state = current_state THEN
        RETURN null;
      END IF;

      row := NEW;
    ELSE
      RAISE EXCEPTION 'Unrecognized TG_OP: %', TG_OP;
    END IF;

    SELECT row_to_json(t)
    INTO message
    FROM (
      SELECT
        'job_change' AS message_type,
        row.id       AS id,
        row.queue    AS queue,

        coalesce(row.data->'tags', '[]'::jsonb) AS tags,

        to_char(row.run_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS run_at,
        to_char(now()      AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS time,

        CASE row.job_class
        WHEN 'ActiveJob::QueueAdapters::QueAdapter::JobWrapper' THEN
          coalesce(
            row.args->0->>'job_class',
            'ActiveJob::QueueAdapters::QueAdapter::JobWrapper'
          )
        ELSE
          row.job_class
        END AS job_class,

        previous_state AS previous_state,
        current_state  AS current_state
    ) t;

    PERFORM pg_notify('que_state', message::text);

    RETURN null;
  END
$$;


--
-- Name: apps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.apps (
    id bigint NOT NULL,
    title text NOT NULL,
    slug text NOT NULL,
    image_name text NOT NULL,
    published_status text NOT NULL,
    description text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: apps_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.apps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: apps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.apps_id_seq OWNED BY public.apps.id;


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
-- Name: journeys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journeys (
    id bigint NOT NULL,
    title text NOT NULL,
    keywords text,
    published_status text NOT NULL,
    slug character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    description text,
    "position" integer DEFAULT 0 NOT NULL,
    image_name text,
    custom_title character varying
);


--
-- Name: journeys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.journeys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: journeys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.journeys_id_seq OWNED BY public.journeys.id;


--
-- Name: notification_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_subscriptions (
    id bigint NOT NULL,
    user_id bigint,
    email character varying,
    type character varying NOT NULL,
    confirmation_token uuid,
    confirmation_sent_at timestamp without time zone,
    confirmed_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    journey_id bigint
);


--
-- Name: notification_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notification_subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notification_subscriptions_id_seq OWNED BY public.notification_subscriptions.id;


--
-- Name: pages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pages (
    id bigint NOT NULL,
    title text NOT NULL,
    content text NOT NULL,
    slug text NOT NULL,
    is_faq boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    keywords text,
    image_name character varying,
    is_searchable boolean DEFAULT false NOT NULL
);


--
-- Name: pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pages_id_seq OWNED BY public.pages.id;


--
-- Name: pg_search_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pg_search_documents (
    id bigint NOT NULL,
    content text,
    tsv_content tsvector,
    searchable_type character varying,
    searchable_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    keywords character varying,
    title character varying,
    tsv_keywords tsvector,
    tsv_title tsvector,
    featured_position integer DEFAULT 0,
    published boolean DEFAULT false,
    featured boolean DEFAULT false NOT NULL
);


--
-- Name: pg_search_documents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pg_search_documents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pg_search_documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pg_search_documents_id_seq OWNED BY public.pg_search_documents.id;


--
-- Name: que_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.que_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: que_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.que_jobs_id_seq OWNED BY public.que_jobs.id;


--
-- Name: que_lockers; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.que_lockers (
    pid integer NOT NULL,
    worker_count integer NOT NULL,
    worker_priorities integer[] NOT NULL,
    ruby_pid integer NOT NULL,
    ruby_hostname text NOT NULL,
    queues text[] NOT NULL,
    listening boolean NOT NULL,
    CONSTRAINT valid_queues CHECK (((array_ndims(queues) = 1) AND (array_length(queues, 1) IS NOT NULL))),
    CONSTRAINT valid_worker_priorities CHECK (((array_ndims(worker_priorities) = 1) AND (array_length(worker_priorities, 1) IS NOT NULL)))
);


--
-- Name: que_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.que_values (
    key text NOT NULL,
    value jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT valid_value CHECK ((jsonb_typeof(value) = 'object'::text))
)
WITH (fillfactor='90');


--
-- Name: quick_tips; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quick_tips (
    id bigint NOT NULL,
    slug character varying NOT NULL,
    title character varying NOT NULL,
    body character varying,
    journey_id bigint,
    step_id bigint,
    application_slug character varying,
    application_title character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: quick_tips_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quick_tips_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quick_tips_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quick_tips_id_seq OWNED BY public.quick_tips.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: steps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.steps (
    id bigint NOT NULL,
    journey_id bigint NOT NULL,
    title text NOT NULL,
    keywords text,
    is_waiting_step boolean DEFAULT false NOT NULL,
    slug character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    description text NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    app_url character varying,
    type character varying DEFAULT 'BasicStep'::character varying NOT NULL,
    app_link_text character varying,
    custom_title character varying
);


--
-- Name: steps_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.steps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: steps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.steps_id_seq OWNED BY public.steps.id;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id bigint NOT NULL,
    step_id bigint NOT NULL,
    title text NOT NULL,
    type character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    url text,
    "position" integer DEFAULT 0 NOT NULL,
    url_title character varying
);


--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tasks_id_seq OWNED BY public.tasks.id;


--
-- Name: user_journeys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_journeys (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    journey_id bigint NOT NULL,
    started_at timestamp without time zone NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_journeys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_journeys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_journeys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_journeys_id_seq OWNED BY public.user_journeys.id;


--
-- Name: user_steps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_steps (
    id bigint NOT NULL,
    user_journey_id bigint NOT NULL,
    step_id bigint NOT NULL,
    status character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_steps_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_steps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_steps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_steps_id_seq OWNED BY public.user_steps.id;


--
-- Name: user_tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_tasks (
    id bigint NOT NULL,
    user_step_id bigint NOT NULL,
    task_id bigint NOT NULL,
    completed_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_tasks_id_seq OWNED BY public.user_tasks.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: apps id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apps ALTER COLUMN id SET DEFAULT nextval('public.apps_id_seq'::regclass);


--
-- Name: journeys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journeys ALTER COLUMN id SET DEFAULT nextval('public.journeys_id_seq'::regclass);


--
-- Name: notification_subscriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_subscriptions ALTER COLUMN id SET DEFAULT nextval('public.notification_subscriptions_id_seq'::regclass);


--
-- Name: pages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pages ALTER COLUMN id SET DEFAULT nextval('public.pages_id_seq'::regclass);


--
-- Name: pg_search_documents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pg_search_documents ALTER COLUMN id SET DEFAULT nextval('public.pg_search_documents_id_seq'::regclass);


--
-- Name: que_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.que_jobs ALTER COLUMN id SET DEFAULT nextval('public.que_jobs_id_seq'::regclass);


--
-- Name: quick_tips id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_tips ALTER COLUMN id SET DEFAULT nextval('public.quick_tips_id_seq'::regclass);


--
-- Name: steps id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.steps ALTER COLUMN id SET DEFAULT nextval('public.steps_id_seq'::regclass);


--
-- Name: tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks ALTER COLUMN id SET DEFAULT nextval('public.tasks_id_seq'::regclass);


--
-- Name: user_journeys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_journeys ALTER COLUMN id SET DEFAULT nextval('public.user_journeys_id_seq'::regclass);


--
-- Name: user_steps id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_steps ALTER COLUMN id SET DEFAULT nextval('public.user_steps_id_seq'::regclass);


--
-- Name: user_tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_tasks ALTER COLUMN id SET DEFAULT nextval('public.user_tasks_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: apps apps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apps
    ADD CONSTRAINT apps_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: journeys journeys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journeys
    ADD CONSTRAINT journeys_pkey PRIMARY KEY (id);


--
-- Name: notification_subscriptions notification_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_subscriptions
    ADD CONSTRAINT notification_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: pages pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pages
    ADD CONSTRAINT pages_pkey PRIMARY KEY (id);


--
-- Name: pg_search_documents pg_search_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pg_search_documents
    ADD CONSTRAINT pg_search_documents_pkey PRIMARY KEY (id);


--
-- Name: que_jobs que_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.que_jobs
    ADD CONSTRAINT que_jobs_pkey PRIMARY KEY (id);


--
-- Name: que_lockers que_lockers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.que_lockers
    ADD CONSTRAINT que_lockers_pkey PRIMARY KEY (pid);


--
-- Name: que_values que_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.que_values
    ADD CONSTRAINT que_values_pkey PRIMARY KEY (key);


--
-- Name: quick_tips quick_tips_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_tips
    ADD CONSTRAINT quick_tips_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: steps steps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.steps
    ADD CONSTRAINT steps_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: user_journeys user_journeys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_journeys
    ADD CONSTRAINT user_journeys_pkey PRIMARY KEY (id);


--
-- Name: user_steps user_steps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_steps
    ADD CONSTRAINT user_steps_pkey PRIMARY KEY (id);


--
-- Name: user_tasks user_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_tasks
    ADD CONSTRAINT user_tasks_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_notification_subscriptions_on_confirmation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_subscriptions_on_confirmation_token ON public.notification_subscriptions USING btree (confirmation_token);


--
-- Name: index_notification_subscriptions_on_journey_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_subscriptions_on_journey_id ON public.notification_subscriptions USING btree (journey_id);


--
-- Name: index_notification_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_subscriptions_on_user_id ON public.notification_subscriptions USING btree (user_id);


--
-- Name: index_pg_search_documents_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pg_search_documents_on_searchable_type_and_searchable_id ON public.pg_search_documents USING btree (searchable_type, searchable_id);


--
-- Name: index_pg_search_documents_on_tsv_content; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pg_search_documents_on_tsv_content ON public.pg_search_documents USING gin (tsv_content);


--
-- Name: index_pg_search_documents_on_tsv_keywords; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pg_search_documents_on_tsv_keywords ON public.pg_search_documents USING gin (tsv_keywords);


--
-- Name: index_pg_search_documents_on_tsv_title; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pg_search_documents_on_tsv_title ON public.pg_search_documents USING gin (tsv_title);


--
-- Name: index_quick_tips_on_journey_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quick_tips_on_journey_id ON public.quick_tips USING btree (journey_id);


--
-- Name: index_quick_tips_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_quick_tips_on_slug ON public.quick_tips USING btree (slug);


--
-- Name: index_quick_tips_on_step_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quick_tips_on_step_id ON public.quick_tips USING btree (step_id);


--
-- Name: index_steps_on_journey_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_steps_on_journey_id ON public.steps USING btree (journey_id);


--
-- Name: index_tasks_on_step_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_step_id ON public.tasks USING btree (step_id);


--
-- Name: index_user_journeys_on_journey_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_journeys_on_journey_id ON public.user_journeys USING btree (journey_id);


--
-- Name: index_user_journeys_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_journeys_on_user_id ON public.user_journeys USING btree (user_id);


--
-- Name: index_user_steps_on_step_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_steps_on_step_id ON public.user_steps USING btree (step_id);


--
-- Name: index_user_steps_on_user_journey_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_steps_on_user_journey_id ON public.user_steps USING btree (user_journey_id);


--
-- Name: index_user_tasks_on_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_tasks_on_task_id ON public.user_tasks USING btree (task_id);


--
-- Name: index_user_tasks_on_user_step_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_tasks_on_user_step_id ON public.user_tasks USING btree (user_step_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_email_lower_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_lower_unique ON public.users USING btree (lower(email));


--
-- Name: que_jobs_args_gin_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX que_jobs_args_gin_idx ON public.que_jobs USING gin (args jsonb_path_ops);


--
-- Name: que_jobs_data_gin_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX que_jobs_data_gin_idx ON public.que_jobs USING gin (data jsonb_path_ops);


--
-- Name: que_poll_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX que_poll_idx ON public.que_jobs USING btree (queue, priority, run_at, id) WHERE ((finished_at IS NULL) AND (expired_at IS NULL));


--
-- Name: que_jobs que_job_notify; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER que_job_notify AFTER INSERT ON public.que_jobs FOR EACH ROW EXECUTE PROCEDURE public.que_job_notify();


--
-- Name: que_jobs que_state_notify; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER que_state_notify AFTER INSERT OR DELETE OR UPDATE ON public.que_jobs FOR EACH ROW EXECUTE PROCEDURE public.que_state_notify();


--
-- Name: pg_search_documents tsv_keywords_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tsv_keywords_update BEFORE INSERT OR UPDATE ON public.pg_search_documents FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('tsv_keywords', 'pg_catalog.simple', 'keywords');


--
-- Name: pg_search_documents tsv_title_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tsv_title_update BEFORE INSERT OR UPDATE ON public.pg_search_documents FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('tsv_title', 'pg_catalog.simple', 'title');


--
-- Name: pg_search_documents tsvectorupdate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE ON public.pg_search_documents FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('tsv_content', 'pg_catalog.simple', 'content');


--
-- Name: quick_tips fk_rails_0a21363dd0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_tips
    ADD CONSTRAINT fk_rails_0a21363dd0 FOREIGN KEY (journey_id) REFERENCES public.journeys(id);


--
-- Name: user_steps fk_rails_270661d7b7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_steps
    ADD CONSTRAINT fk_rails_270661d7b7 FOREIGN KEY (user_journey_id) REFERENCES public.user_journeys(id);


--
-- Name: notification_subscriptions fk_rails_2bf71acda7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_subscriptions
    ADD CONSTRAINT fk_rails_2bf71acda7 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: notification_subscriptions fk_rails_2fb637afd2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_subscriptions
    ADD CONSTRAINT fk_rails_2fb637afd2 FOREIGN KEY (journey_id) REFERENCES public.journeys(id);


--
-- Name: user_steps fk_rails_56d22858e3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_steps
    ADD CONSTRAINT fk_rails_56d22858e3 FOREIGN KEY (step_id) REFERENCES public.steps(id);


--
-- Name: user_tasks fk_rails_5a3f03c742; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_tasks
    ADD CONSTRAINT fk_rails_5a3f03c742 FOREIGN KEY (task_id) REFERENCES public.tasks(id);


--
-- Name: user_journeys fk_rails_70185eaf12; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_journeys
    ADD CONSTRAINT fk_rails_70185eaf12 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: quick_tips fk_rails_8c50350cb1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_tips
    ADD CONSTRAINT fk_rails_8c50350cb1 FOREIGN KEY (step_id) REFERENCES public.steps(id);


--
-- Name: tasks fk_rails_bed40c4f02; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_rails_bed40c4f02 FOREIGN KEY (step_id) REFERENCES public.steps(id);


--
-- Name: user_tasks fk_rails_eef61d1fdc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_tasks
    ADD CONSTRAINT fk_rails_eef61d1fdc FOREIGN KEY (user_step_id) REFERENCES public.user_steps(id);


--
-- Name: user_journeys fk_rails_fb72d96772; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_journeys
    ADD CONSTRAINT fk_rails_fb72d96772 FOREIGN KEY (journey_id) REFERENCES public.journeys(id);


--
-- Name: steps fk_rails_fc12f91020; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.steps
    ADD CONSTRAINT fk_rails_fc12f91020 FOREIGN KEY (journey_id) REFERENCES public.journeys(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20181201094003'),
('20181201104550'),
('20181201110114'),
('20181201114726'),
('20181201121129'),
('20181201121130'),
('20181201130356'),
('20181201131820'),
('20181201145710'),
('20181201173440'),
('20181201173548'),
('20181201174333'),
('20190116201226'),
('20190117171028'),
('20190118111308'),
('20190122112950'),
('20190301173059'),
('20190321100731'),
('20190411095826'),
('20190411104731'),
('20190423124647'),
('20190423214925'),
('20190424074855'),
('20190529210530'),
('20190529210630'),
('20190608102251'),
('20190608130459'),
('20190608135807'),
('20190608201245'),
('20190914143708'),
('20190914164512'),
('20190915104202'),
('20191209121011'),
('20200316102804'),
('20200316104715');


