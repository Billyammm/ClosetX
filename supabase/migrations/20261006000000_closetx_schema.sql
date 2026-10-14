-- ClosetX schema for a new Supabase project.
--
-- Roles:
--   shopper  - browses published designs (signing in is optional).
--   designer - creates one brand and uploads front/back T-shirt artwork.
--
-- Run once in the SQL Editor of a fresh project.

begin;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Profiles (one per auth user, created automatically on sign-up)
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text not null default '',
  role text not null default 'shopper'
    check (role in ('shopper', 'designer')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create or replace function public.is_closetx_designer()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'designer'
  );
$$;

revoke all on function public.is_closetx_designer() from public;
grant execute on function public.is_closetx_designer() to authenticated;

create or replace function public.create_closetx_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_role text;
begin
  requested_role := new.raw_user_meta_data ->> 'role';
  if requested_role is null
     or requested_role not in ('shopper', 'designer') then
    requested_role := 'shopper';
  end if;

  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    lower(coalesce(new.email, '')),
    coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
      split_part(coalesce(new.email, ''), '@', 1)
    ),
    requested_role
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

revoke all on function public.create_closetx_profile() from public;
revoke all on function public.create_closetx_profile()
  from anon, authenticated;

create trigger closetx_create_profile_after_signup
after insert on auth.users
for each row execute function public.create_closetx_profile();

-- ---------------------------------------------------------------------------
-- Brands (one per designer)
-- ---------------------------------------------------------------------------

create table public.brands (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references public.profiles (id)
    on delete cascade,
  name text not null check (char_length(btrim(name)) between 2 and 60),
  bio text not null default '',
  location text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index brands_name_unique on public.brands (lower(name));

create trigger brands_set_updated_at
before update on public.brands
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Designs (front/back artwork printed on the 3D shirt)
-- ---------------------------------------------------------------------------

create table public.designs (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references public.brands (id) on delete cascade,
  designer_id uuid not null references public.profiles (id)
    on delete cascade,
  title text not null check (char_length(btrim(title)) between 2 and 80),
  description text not null default '',
  price integer not null check (price >= 0),
  category text not null default 'T-Shirts',
  shirt_color text not null default '#F2F2F2'
    check (shirt_color ~ '^#[0-9A-Fa-f]{6}$'),
  front_image_url text not null,
  back_image_url text not null,
  front_image_path text not null,
  back_image_path text not null,
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index designs_published_created_idx
  on public.designs (created_at desc) where is_published;
create index designs_designer_idx on public.designs (designer_id);

create trigger designs_set_updated_at
before update on public.designs
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.brands enable row level security;
alter table public.designs enable row level security;

revoke all on table public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;

create policy profiles_read_own
on public.profiles for select to authenticated
using (id = (select auth.uid()));

create policy profiles_update_own
on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

revoke all on table public.brands from anon, authenticated;
grant select on public.brands to anon, authenticated;
grant insert (owner_id, name, bio, location) on public.brands to authenticated;
grant update (name, bio, location) on public.brands to authenticated;
grant delete on public.brands to authenticated;

create policy brands_read_all
on public.brands for select to anon, authenticated
using (true);

create policy brands_create_own
on public.brands for insert to authenticated
with check (
  owner_id = (select auth.uid())
  and (select public.is_closetx_designer())
);

create policy brands_update_own
on public.brands for update to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

create policy brands_delete_own
on public.brands for delete to authenticated
using (owner_id = (select auth.uid()));

revoke all on table public.designs from anon, authenticated;
grant select on public.designs to anon, authenticated;
grant insert (
  brand_id, designer_id, title, description, price, category, shirt_color,
  front_image_url, back_image_url, front_image_path, back_image_path,
  is_published
) on public.designs to authenticated;
grant update (
  title, description, price, category, shirt_color,
  front_image_url, back_image_url, front_image_path, back_image_path,
  is_published
) on public.designs to authenticated;
grant delete on public.designs to authenticated;

create policy designs_read_published_or_own
on public.designs for select to anon, authenticated
using (
  is_published
  or designer_id = (select auth.uid())
);

create policy designs_create_for_own_brand
on public.designs for insert to authenticated
with check (
  designer_id = (select auth.uid())
  and (select public.is_closetx_designer())
  and exists (
    select 1 from public.brands
    where brands.id = designs.brand_id
      and brands.owner_id = (select auth.uid())
  )
);

create policy designs_update_own
on public.designs for update to authenticated
using (designer_id = (select auth.uid()))
with check (designer_id = (select auth.uid()));

create policy designs_delete_own
on public.designs for delete to authenticated
using (designer_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Storage: public bucket for design artwork, one folder per designer
-- ({user_id}/{file}). Anyone can view; only the owner can write.
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'design-images',
  'design-images',
  true,
  10485760,
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do nothing;

create policy design_images_insert_own_folder
on storage.objects for insert to authenticated
with check (
  bucket_id = 'design-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (select public.is_closetx_designer())
);

create policy design_images_update_own_folder
on storage.objects for update to authenticated
using (
  bucket_id = 'design-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy design_images_delete_own_folder
on storage.objects for delete to authenticated
using (
  bucket_id = 'design-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

commit;
