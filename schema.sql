DROP TABLE IF EXISTS passes, satellites;

CREATE OR REPLACE FUNCTION seconds(timestamp with time zone) RETURNS timestamp
AS $$ SELECT date_trunc('second', $1 at time zone 'UTC') $$
LANGUAGE SQL
IMMUTABLE;

CREATE TABLE satellites (
    catalog_number  integer PRIMARY KEY,
    name            text
);

CREATE TABLE passes (
    satellite_catnum  integer REFERENCES satellites(catalog_number),
    start_time        timestamptz,
    end_time          timestamptz,
    max_elevation     real
);
CREATE UNIQUE INDEX passes_pkey ON passes(satellite_catnum, seconds(start_time))
