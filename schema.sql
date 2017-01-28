DROP TABLE IF EXISTS passes, satellites;

CREATE OR REPLACE FUNCTION seconds(timestamp with time zone) RETURNS timestamp
AS $$ SELECT date_trunc('second', $1 at time zone 'UTC') $$
LANGUAGE SQL
IMMUTABLE;

CREATE TABLE satellites (
    catalog_number    integer PRIMARY KEY,
    name              text NOT NULL
);

CREATE TABLE passes (
    id                uuid PRIMARY KEY,
    satellite_catnum  integer NOT NULL REFERENCES satellites(catalog_number),
    start_time        timestamptz NOT NULL,
    end_time          timestamptz NOT NULL,
    max_elevation     real NOT NULL
);
CREATE UNIQUE INDEX passes_unique_time ON passes(satellite_catnum, seconds(start_time));
