SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

CREATE TABLE lastsaw (
    person character varying NOT NULL,
    "time" timestamp with time zone,
    lastsaid character varying
);

ALTER TABLE ONLY lastsaw
    ADD CONSTRAINT lastsaw_pkey PRIMARY KEY (person);

CREATE TABLE memory (
    keyword character varying,
    definition character varying,
    ro boolean,
    submitter character varying,
    "time" timestamp with time zone,
    ordered boolean
);

CREATE INDEX memory_keyword ON memory USING btree (keyword);
