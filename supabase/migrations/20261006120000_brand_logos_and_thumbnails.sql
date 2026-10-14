-- Brand logos and designer-uploaded product thumbnails.
--
-- brands.logo_*      - each brand's own logo, shown next to its name in the shop.
-- designs.thumbnail_* - the product photo shown in the featured list; the
--                       front/back artwork is still what prints on the 3D shirt.
--
-- Files live in the existing public `design-images` bucket under the
-- designer's own folder, so the storage policies already cover them.
--
-- Run once in the SQL Editor after 20261006000000_closetx_schema.sql.

begin;

alter table public.brands
  add column logo_url text,
  add column logo_path text;

alter table public.designs
  add column thumbnail_url text,
  add column thumbnail_path text;

grant insert (logo_url, logo_path) on public.brands to authenticated;
grant update (logo_url, logo_path) on public.brands to authenticated;

grant insert (thumbnail_url, thumbnail_path) on public.designs to authenticated;
grant update (thumbnail_url, thumbnail_path) on public.designs to authenticated;

commit;
