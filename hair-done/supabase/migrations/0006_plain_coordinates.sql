-- Plain numbers next to the geography columns, so the app reads coordinates without decoding PostGIS.
-- Write locations as EWKT text: 'SRID=4326;POINT(<lng> <lat>)'.
alter table addresses
  add column lat double precision generated always as (st_y(location::geometry)) stored,
  add column lng double precision generated always as (st_x(location::geometry)) stored;
alter table pros
  add column lat double precision generated always as (st_y(location::geometry)) stored,
  add column lng double precision generated always as (st_x(location::geometry)) stored;
