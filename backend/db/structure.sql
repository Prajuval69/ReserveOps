SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: booking_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.booking_events (
    id bigint NOT NULL,
    booking_id bigint NOT NULL,
    actor_id bigint,
    from_status character varying,
    to_status character varying,
    action character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL
);


--
-- Name: booking_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.booking_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: booking_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.booking_events_id_seq OWNED BY public.booking_events.id;


--
-- Name: bookings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bookings (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    resource_id bigint NOT NULL,
    starts_at timestamp(6) with time zone NOT NULL,
    ends_at timestamp(6) with time zone NOT NULL,
    status character varying NOT NULL,
    attendee_count integer DEFAULT 1 NOT NULL,
    purpose character varying NOT NULL,
    approval_expires_at timestamp(6) with time zone,
    decided_at timestamp(6) with time zone,
    approved_by_id bigint,
    cancellation_reason text,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT positive_attendee_count CHECK ((attendee_count >= 1)),
    CONSTRAINT positive_booking_interval CHECK ((ends_at > starts_at)),
    CONSTRAINT valid_booking_status CHECK (((status)::text = ANY (ARRAY[('pending_approval'::character varying)::text, ('confirmed'::character varying)::text, ('waitlisted'::character varying)::text, ('rejected'::character varying)::text, ('cancelled'::character varying)::text, ('expired'::character varying)::text, ('completed'::character varying)::text]))),
    CONSTRAINT valid_hold_deadline CHECK ((((status)::text <> 'pending_approval'::text) OR ((approval_expires_at IS NOT NULL) AND (approval_expires_at <= starts_at))))
);


--
-- Name: bookings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bookings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bookings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bookings_id_seq OWNED BY public.bookings.id;


--
-- Name: locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.locations (
    id bigint NOT NULL,
    name character varying NOT NULL,
    timezone character varying DEFAULT 'Asia/Kolkata'::character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.locations_id_seq OWNED BY public.locations.id;


--
-- Name: manager_location_scopes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.manager_location_scopes (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    location_id bigint NOT NULL
);


--
-- Name: manager_location_scopes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.manager_location_scopes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: manager_location_scopes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.manager_location_scopes_id_seq OWNED BY public.manager_location_scopes.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    booking_id bigint,
    notification_key character varying NOT NULL,
    kind character varying NOT NULL,
    title character varying NOT NULL,
    body text NOT NULL,
    read_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL
);


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: resource_blackouts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resource_blackouts (
    id bigint NOT NULL,
    resource_id bigint NOT NULL,
    starts_at timestamp(6) with time zone NOT NULL,
    ends_at timestamp(6) with time zone NOT NULL,
    reason character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT positive_blackout CHECK ((ends_at > starts_at))
);


--
-- Name: resource_blackouts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.resource_blackouts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resource_blackouts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.resource_blackouts_id_seq OWNED BY public.resource_blackouts.id;


--
-- Name: resource_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resource_categories (
    id bigint NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: resource_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.resource_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resource_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.resource_categories_id_seq OWNED BY public.resource_categories.id;


--
-- Name: resources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resources (
    id bigint NOT NULL,
    resource_category_id bigint NOT NULL,
    location_id bigint NOT NULL,
    name character varying NOT NULL,
    identifier character varying NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    occupants_capacity integer DEFAULT 1 NOT NULL,
    requires_approval boolean DEFAULT false NOT NULL,
    min_minutes integer DEFAULT 15 NOT NULL,
    max_minutes integer DEFAULT 480 NOT NULL,
    advance_days integer DEFAULT 60 NOT NULL,
    opens_at character varying DEFAULT '08:00'::character varying NOT NULL,
    closes_at character varying DEFAULT '20:00'::character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT valid_opening_hours CHECK ((((opens_at)::text ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'::text) AND ((closes_at)::text ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'::text) AND ((opens_at)::text < (closes_at)::text))),
    CONSTRAINT valid_resource_policy CHECK (((occupants_capacity > 0) AND (min_minutes > 0) AND (max_minutes >= min_minutes) AND (advance_days > 0)))
);


--
-- Name: resources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.resources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.resources_id_seq OWNED BY public.resources.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying NOT NULL,
    password_digest character varying NOT NULL,
    display_name character varying NOT NULL,
    role character varying DEFAULT 'employee'::character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    session_version integer DEFAULT 0 NOT NULL,
    CONSTRAINT normalized_email CHECK (((email)::text = lower((email)::text))),
    CONSTRAINT valid_user_role CHECK (((role)::text = ANY (ARRAY[('employee'::character varying)::text, ('manager'::character varying)::text, ('admin'::character varying)::text])))
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
-- Name: booking_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_events ALTER COLUMN id SET DEFAULT nextval('public.booking_events_id_seq'::regclass);


--
-- Name: bookings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings ALTER COLUMN id SET DEFAULT nextval('public.bookings_id_seq'::regclass);


--
-- Name: locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations ALTER COLUMN id SET DEFAULT nextval('public.locations_id_seq'::regclass);


--
-- Name: manager_location_scopes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manager_location_scopes ALTER COLUMN id SET DEFAULT nextval('public.manager_location_scopes_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: resource_blackouts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_blackouts ALTER COLUMN id SET DEFAULT nextval('public.resource_blackouts_id_seq'::regclass);


--
-- Name: resource_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_categories ALTER COLUMN id SET DEFAULT nextval('public.resource_categories_id_seq'::regclass);


--
-- Name: resources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources ALTER COLUMN id SET DEFAULT nextval('public.resources_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: booking_events booking_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_events
    ADD CONSTRAINT booking_events_pkey PRIMARY KEY (id);


--
-- Name: bookings bookings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_pkey PRIMARY KEY (id);


--
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- Name: manager_location_scopes manager_location_scopes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manager_location_scopes
    ADD CONSTRAINT manager_location_scopes_pkey PRIMARY KEY (id);


--
-- Name: bookings no_active_resource_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT no_active_resource_overlap EXCLUDE USING gist (resource_id WITH =, tstzrange(starts_at, ends_at, '[)'::text) WITH &&) WHERE (((status)::text = ANY (ARRAY[('pending_approval'::character varying)::text, ('confirmed'::character varying)::text])));


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: resource_blackouts resource_blackouts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_blackouts
    ADD CONSTRAINT resource_blackouts_pkey PRIMARY KEY (id);


--
-- Name: resource_categories resource_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_categories
    ADD CONSTRAINT resource_categories_pkey PRIMARY KEY (id);


--
-- Name: resources resources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources
    ADD CONSTRAINT resources_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_booking_events_on_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_booking_events_on_actor_id ON public.booking_events USING btree (actor_id);


--
-- Name: index_booking_events_on_booking_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_booking_events_on_booking_id ON public.booking_events USING btree (booking_id);


--
-- Name: index_bookings_on_approved_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookings_on_approved_by_id ON public.bookings USING btree (approved_by_id);


--
-- Name: index_bookings_on_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookings_on_resource_id ON public.bookings USING btree (resource_id);


--
-- Name: index_bookings_on_resource_id_and_starts_at_and_ends_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookings_on_resource_id_and_starts_at_and_ends_at ON public.bookings USING btree (resource_id, starts_at, ends_at);


--
-- Name: index_bookings_on_status_and_approval_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookings_on_status_and_approval_expires_at ON public.bookings USING btree (status, approval_expires_at);


--
-- Name: index_bookings_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookings_on_user_id ON public.bookings USING btree (user_id);


--
-- Name: index_bookings_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookings_on_user_id_and_created_at ON public.bookings USING btree (user_id, created_at);


--
-- Name: index_locations_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_locations_on_name ON public.locations USING btree (name);


--
-- Name: index_manager_location_scopes_on_location_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_manager_location_scopes_on_location_id ON public.manager_location_scopes USING btree (location_id);


--
-- Name: index_manager_location_scopes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_manager_location_scopes_on_user_id ON public.manager_location_scopes USING btree (user_id);


--
-- Name: index_manager_location_scopes_on_user_id_and_location_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_manager_location_scopes_on_user_id_and_location_id ON public.manager_location_scopes USING btree (user_id, location_id);


--
-- Name: index_notifications_on_booking_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_booking_id ON public.notifications USING btree (booking_id);


--
-- Name: index_notifications_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_user_id ON public.notifications USING btree (user_id);


--
-- Name: index_notifications_on_user_id_and_notification_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_notifications_on_user_id_and_notification_key ON public.notifications USING btree (user_id, notification_key);


--
-- Name: index_notifications_on_user_id_and_read_at_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_user_id_and_read_at_and_created_at ON public.notifications USING btree (user_id, read_at, created_at);


--
-- Name: index_resource_blackouts_on_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_resource_blackouts_on_resource_id ON public.resource_blackouts USING btree (resource_id);


--
-- Name: index_resource_categories_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_resource_categories_on_slug ON public.resource_categories USING btree (slug);


--
-- Name: index_resources_on_location_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_resources_on_location_id ON public.resources USING btree (location_id);


--
-- Name: index_resources_on_location_id_and_identifier; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_resources_on_location_id_and_identifier ON public.resources USING btree (location_id, identifier);


--
-- Name: index_resources_on_resource_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_resources_on_resource_category_id ON public.resources USING btree (resource_category_id);


--
-- Name: index_users_on_lower_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_lower_email ON public.users USING btree (lower((email)::text));


--
-- Name: one_waitlist_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX one_waitlist_entry ON public.bookings USING btree (user_id, resource_id, starts_at, ends_at) WHERE ((status)::text = 'waitlisted'::text);


--
-- Name: bookings fk_rails_03c211d719; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT fk_rails_03c211d719 FOREIGN KEY (approved_by_id) REFERENCES public.users(id);


--
-- Name: booking_events fk_rails_5b9e706835; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_events
    ADD CONSTRAINT fk_rails_5b9e706835 FOREIGN KEY (actor_id) REFERENCES public.users(id);


--
-- Name: manager_location_scopes fk_rails_639c29e280; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manager_location_scopes
    ADD CONSTRAINT fk_rails_639c29e280 FOREIGN KEY (location_id) REFERENCES public.locations(id);


--
-- Name: resource_blackouts fk_rails_65d12ff209; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_blackouts
    ADD CONSTRAINT fk_rails_65d12ff209 FOREIGN KEY (resource_id) REFERENCES public.resources(id);


--
-- Name: bookings fk_rails_a270ca984f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT fk_rails_a270ca984f FOREIGN KEY (resource_id) REFERENCES public.resources(id);


--
-- Name: notifications fk_rails_b080fb4855; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_rails_b080fb4855 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: resources fk_rails_b4905d5269; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources
    ADD CONSTRAINT fk_rails_b4905d5269 FOREIGN KEY (resource_category_id) REFERENCES public.resource_categories(id);


--
-- Name: booking_events fk_rails_bd4278e1bd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_events
    ADD CONSTRAINT fk_rails_bd4278e1bd FOREIGN KEY (booking_id) REFERENCES public.bookings(id);


--
-- Name: notifications fk_rails_c000af975d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_rails_c000af975d FOREIGN KEY (booking_id) REFERENCES public.bookings(id);


--
-- Name: resources fk_rails_eb0cde6fb2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources
    ADD CONSTRAINT fk_rails_eb0cde6fb2 FOREIGN KEY (location_id) REFERENCES public.locations(id);


--
-- Name: bookings fk_rails_ef0571f117; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT fk_rails_ef0571f117 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: manager_location_scopes fk_rails_f36fa95a34; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manager_location_scopes
    ADD CONSTRAINT fk_rails_f36fa95a34 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261101000001'),
('20261101000000');

