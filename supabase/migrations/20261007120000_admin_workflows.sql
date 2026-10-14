-- Admin review workflows for designer applications, uploaded designs and feedback.

begin;

create or replace function public.is_closetx_admin()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select auth.jwt() -> 'app_metadata' ->> 'closetx_admin') = 'true',
    false
  );
$$;

revoke all on function public.is_closetx_admin() from public;
grant execute on function public.is_closetx_admin() to authenticated;

alter table public.profiles
  add column designer_status text not null default 'approved'
    check (designer_status in ('pending', 'approved', 'rejected')),
  add column designer_rejection_reason text,
  add column designer_reviewed_at timestamptz;

update public.profiles
set designer_status = 'approved'
where role = 'designer';

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

  insert into public.profiles (
    id, email, full_name, role, designer_status
  )
  values (
    new.id,
    lower(coalesce(new.email, '')),
    coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
      split_part(coalesce(new.email, ''), '@', 1)
    ),
    requested_role,
    case when requested_role = 'designer' then 'pending' else 'approved' end
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

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
      and designer_status = 'approved'
  );
$$;

create or replace function public.protect_closetx_review_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not public.is_closetx_admin() then
    if new.role is distinct from old.role
       or new.designer_status is distinct from old.designer_status
       or new.designer_rejection_reason is distinct from old.designer_rejection_reason
       or new.designer_reviewed_at is distinct from old.designer_reviewed_at then
      raise exception 'Only a ClosetX admin can review designer applications.';
    end if;
  end if;
  return new;
end;
$$;

create trigger profiles_protect_closetx_review_fields
before update on public.profiles
for each row execute function public.protect_closetx_review_fields();

grant select on public.profiles to authenticated;
grant update (
  designer_status, designer_rejection_reason, designer_reviewed_at
) on public.profiles to authenticated;

create policy profiles_admin_read
on public.profiles for select to authenticated
using ((select public.is_closetx_admin()));

create policy profiles_admin_review
on public.profiles for update to authenticated
using ((select public.is_closetx_admin()))
with check ((select public.is_closetx_admin()));

alter table public.designs
  add column review_status text not null default 'approved'
    check (review_status in ('pending', 'approved', 'rejected')),
  add column rejection_reason text,
  add column reviewed_at timestamptz;

alter table public.designs
  alter column review_status set default 'pending',
  alter column is_published set default false;

create or replace function public.protect_closetx_design_review()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not public.is_closetx_admin() then
    if new.review_status is distinct from old.review_status
       or new.rejection_reason is distinct from old.rejection_reason
       or new.reviewed_at is distinct from old.reviewed_at then
      raise exception 'Only a ClosetX admin can review designs.';
    end if;

    if new.title is distinct from old.title
       or new.description is distinct from old.description
       or new.price is distinct from old.price
       or new.category is distinct from old.category
       or new.shirt_color is distinct from old.shirt_color
       or new.thumbnail_url is distinct from old.thumbnail_url
       or new.thumbnail_path is distinct from old.thumbnail_path
       or new.front_image_url is distinct from old.front_image_url
       or new.back_image_url is distinct from old.back_image_url
       or new.front_image_path is distinct from old.front_image_path
       or new.back_image_path is distinct from old.back_image_path then
      new.review_status := 'pending';
      new.rejection_reason := null;
      new.reviewed_at := null;
      new.is_published := false;
    elsif new.is_published is distinct from old.is_published
       and old.review_status <> 'approved' then
      raise exception 'A design must be approved before it can be published.';
    end if;
  end if;
  return new;
end;
$$;

create trigger designs_protect_closetx_review
before update on public.designs
for each row execute function public.protect_closetx_design_review();

grant select on public.designs to authenticated;
grant update (review_status, rejection_reason, reviewed_at)
  on public.designs to authenticated;

create policy designs_admin_read
on public.designs for select to authenticated
using ((select public.is_closetx_admin()));

create policy designs_admin_review
on public.designs for update to authenticated
using ((select public.is_closetx_admin()))
with check ((select public.is_closetx_admin()));

create table public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles (id) on delete set null,
  author_name text not null default '',
  author_email text not null default '',
  message text not null
    check (char_length(btrim(message)) between 1 and 2000),
  rating integer check (rating between 1 and 5),
  created_at timestamptz not null default now()
);

alter table public.feedback enable row level security;
revoke all on table public.feedback from anon, authenticated;
grant insert (user_id, author_name, author_email, message, rating)
  on public.feedback to anon, authenticated;
grant select on public.feedback to authenticated;

create policy feedback_submit
on public.feedback for insert to anon, authenticated
with check (
  user_id is null
  or user_id = (select auth.uid())
);

create policy feedback_admin_read
on public.feedback for select to authenticated
using ((select public.is_closetx_admin()));

commit;
