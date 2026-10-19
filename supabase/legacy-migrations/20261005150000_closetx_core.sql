begin;

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

create or replace function public.is_closetx_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admins
    where user_id = (select auth.uid())
  );
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
  );
$$;

create or replace function public.guard_design_review_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status
     and (select auth.uid()) is not null
     and not (select public.is_closetx_admin())
     and not (
       (select public.is_closetx_designer())
       and old.status = 'rejected'
       and new.status = 'pending'
     ) then
    raise exception 'Only an admin can approve or reject a design.';
  end if;

  return new;
end;
$$;

create or replace function public.guard_designer_verification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.is_verified is distinct from old.is_verified
     and not (select public.is_closetx_admin()) then
    raise exception 'Only an admin can change designer verification.';
  end if;

  return new;
end;
$$;

revoke all on function public.is_closetx_admin() from public;
revoke all on function public.is_closetx_designer() from public;
grant execute on function public.is_closetx_admin() to anon, authenticated;
grant execute on function public.is_closetx_designer() to authenticated;
revoke all on function public.guard_design_review_status() from public;
revoke all on function public.guard_design_review_status()
  from anon, authenticated;
revoke all on function public.guard_designer_verification() from public;
revoke all on function public.guard_designer_verification()
  from anon, authenticated;

create or replace function public.create_closetx_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_role text;
  requested_name text;
begin
  requested_role := new.raw_user_meta_data ->> 'role';
  if requested_role is null
     or requested_role not in ('guest', 'designer') then
    requested_role := 'guest';
  end if;

  requested_name := nullif(
    btrim(new.raw_user_meta_data ->> 'full_name'),
    ''
  );

  if new.email is not null then
    insert into public.profiles (id, email, full_name, role)
    values (
      new.id,
      lower(new.email),
      coalesce(requested_name, split_part(new.email, '@', 1)),
      requested_role
    )
    on conflict (id) do update
    set email = excluded.email;
  end if;

  return new;
end;
$$;

revoke all on function public.create_closetx_profile() from public;
revoke all on function public.create_closetx_profile()
  from anon, authenticated;

drop trigger if exists closetx_create_profile_after_signup on auth.users;
create trigger closetx_create_profile_after_signup
after insert on auth.users
for each row execute function public.create_closetx_profile();

insert into public.profiles (id, email, full_name, role)
select
  users.id,
  lower(users.email),
  coalesce(
    nullif(btrim(users.raw_user_meta_data ->> 'full_name'), ''),
    split_part(users.email, '@', 1)
  ),
  case
    when users.raw_user_meta_data ->> 'role' = 'designer' then 'designer'
    else 'guest'
  end
from auth.users as users
where users.email is not null
  and not exists (
    select 1 from public.profiles where profiles.id = users.id
  )
on conflict (id) do nothing;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists designs_set_updated_at on public.designs;
create trigger designs_set_updated_at
before update on public.designs
for each row execute function public.set_updated_at();

drop trigger if exists designer_profiles_set_updated_at
  on public.designer_profiles;
create trigger designer_profiles_set_updated_at
before update on public.designer_profiles
for each row execute function public.set_updated_at();

drop trigger if exists design_comments_set_updated_at
  on public.design_comments;
create trigger design_comments_set_updated_at
before update on public.design_comments
for each row execute function public.set_updated_at();

alter table public.designer_profiles
  alter column is_verified set default false;

drop trigger if exists designer_profiles_guard_verification
  on public.designer_profiles;
create trigger designer_profiles_guard_verification
before update on public.designer_profiles
for each row execute function public.guard_designer_verification();

drop trigger if exists designs_guard_review_status on public.designs;
create trigger designs_guard_review_status
before update on public.designs
for each row execute function public.guard_design_review_status();

alter table public.profiles enable row level security;
alter table public.admins enable row level security;
alter table public.designer_profiles enable row level security;
alter table public.designs enable row level security;
alter table public.design_likes enable row level security;
alter table public.design_comments enable row level security;
alter table public.favorites enable row level security;
alter table public.notifications enable row level security;

-- These app-table policies are replaced below with rules for the existing
-- profile, designer, design, engagement, and notification schema.
do $$
declare
  target_table text;
  existing_policy record;
begin
  foreach target_table in array array[
    'profiles',
    'designer_profiles',
    'designs',
    'design_likes',
    'design_comments',
    'favorites',
    'notifications'
  ]
  loop
    for existing_policy in
      select policyname
      from pg_policies
      where schemaname = 'public'
        and tablename = target_table
    loop
      execute format(
        'drop policy %I on public.%I',
        existing_policy.policyname,
        target_table
      );
    end loop;
  end loop;
end;
$$;

revoke all on table public.admins from anon, authenticated;

revoke all on table public.profiles from anon, authenticated;
grant select (id, full_name, role) on public.profiles to anon;
grant select on public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;

create policy profiles_read_own_or_admin
on public.profiles
for select
to authenticated
using (
  id = (select auth.uid())
  or (select public.is_closetx_admin())
);

create policy profiles_read_designers_with_approved_designs
on public.profiles
for select
to anon, authenticated
using (
  role = 'designer'
  and exists (
    select 1
    from public.designs
    where designs.designer_id = profiles.id
      and designs.status = 'approved'
  )
);

create policy profiles_update_own_or_admin
on public.profiles
for update
to authenticated
using (
  id = (select auth.uid())
  or (select public.is_closetx_admin())
)
with check (
  id = (select auth.uid())
  or (select public.is_closetx_admin())
);

revoke all on table public.designer_profiles from anon, authenticated;
grant select on public.designer_profiles to anon, authenticated;
grant insert (
  id,
  user_id,
  brand_name,
  location,
  shopee_link,
  tiktok_link,
  lazada_link,
  bio,
  profile_image_url,
  facebook_link,
  instagram_link,
  twitter_link,
  website_link
) on public.designer_profiles to authenticated;
grant update (
  brand_name,
  location,
  shopee_link,
  tiktok_link,
  lazada_link,
  bio,
  profile_image_url,
  facebook_link,
  instagram_link,
  twitter_link,
  website_link
) on public.designer_profiles to authenticated;
grant update (is_verified)
  on public.designer_profiles to authenticated;

create policy designer_profiles_read_verified_or_owner
on public.designer_profiles
for select
to anon, authenticated
using (
  is_verified is true
  or user_id = (select auth.uid())
  or (select public.is_closetx_admin())
);

create policy designer_profiles_create_for_self
on public.designer_profiles
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and (select public.is_closetx_designer())
  and coalesce(is_verified, false) is false
);

create policy designer_profiles_update_own_or_admin
on public.designer_profiles
for update
to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_closetx_admin())
)
with check (
  user_id = (select auth.uid())
  or (select public.is_closetx_admin())
);

create policy admins_update_designer_profiles
on public.designer_profiles
for update
to authenticated
using ((select public.is_closetx_admin()))
with check ((select public.is_closetx_admin()));

revoke all on table public.designs from anon, authenticated;
grant select on public.designs to anon, authenticated;
grant insert (
  designer_id,
  title,
  description,
  front_image_url,
  back_image_url,
  price,
  category,
  status,
  lens_id,
  lens_group_id
) on public.designs to authenticated;
grant update (
  title,
  description,
  front_image_url,
  back_image_url,
  price,
  category,
  status,
  rejection_reason,
  lens_id,
  lens_group_id
) on public.designs to authenticated;
grant delete on public.designs to authenticated;

create policy designs_read_approved_owner_or_admin
on public.designs
for select
to anon, authenticated
using (
  status = 'approved'
  or designer_id = (select auth.uid())
  or (select public.is_closetx_admin())
);

create policy designs_create_pending_for_designer
on public.designs
for insert
to authenticated
with check (
  designer_id = (select auth.uid())
  and (select public.is_closetx_designer())
  and status = 'pending'
);

create policy designers_update_own_unapproved_designs
on public.designs
for update
to authenticated
using (
  designer_id = (select auth.uid())
  and (select public.is_closetx_designer())
  and status in ('pending', 'rejected')
)
with check (
  designer_id = (select auth.uid())
  and (select public.is_closetx_designer())
  and status in ('pending', 'rejected')
);

create policy admins_update_design_reviews
on public.designs
for update
to authenticated
using ((select public.is_closetx_admin()))
with check ((select public.is_closetx_admin()));

create policy designers_delete_own_unapproved_designs
on public.designs
for delete
to authenticated
using (
  designer_id = (select auth.uid())
  and (select public.is_closetx_designer())
  and status in ('pending', 'rejected')
);

create policy admins_delete_designs
on public.designs
for delete
to authenticated
using ((select public.is_closetx_admin()));

revoke all on table public.design_likes from anon, authenticated;
grant select, insert, delete on public.design_likes to authenticated;

create policy design_likes_read_own
on public.design_likes
for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_closetx_admin())
);

create policy design_likes_add_own_to_approved_designs
on public.design_likes
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.designs
    where designs.id = design_likes.design_id
      and designs.status = 'approved'
  )
);

create policy design_likes_remove_own
on public.design_likes
for delete
to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_closetx_admin())
);

revoke all on table public.design_comments from anon, authenticated;
grant select (id, design_id, comment_text, rating, created_at, updated_at)
  on public.design_comments to anon;
grant select on public.design_comments to authenticated;
grant insert (design_id, user_id, comment_text, rating)
  on public.design_comments to authenticated;
grant update (comment_text, rating)
  on public.design_comments to authenticated;
grant delete on public.design_comments to authenticated;

create policy design_comments_read_approved_or_own
on public.design_comments
for select
to anon, authenticated
using (
  exists (
    select 1 from public.designs
    where designs.id = design_comments.design_id
      and designs.status = 'approved'
  )
  or user_id = (select auth.uid())
  or (select public.is_closetx_admin())
);

create policy design_comments_add_own_to_approved_designs
on public.design_comments
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.designs
    where designs.id = design_comments.design_id
      and designs.status = 'approved'
  )
);

create policy design_comments_update_own
on public.design_comments
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy design_comments_delete_own_or_admin
on public.design_comments
for delete
to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_closetx_admin())
);

revoke all on table public.favorites from anon, authenticated;
grant select, insert, delete on public.favorites to authenticated;

create policy favorites_read_own
on public.favorites
for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_closetx_admin())
);

create policy favorites_add_own_approved_design
on public.favorites
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.designs
    where designs.id = favorites.design_id
      and designs.status = 'approved'
  )
);

create policy favorites_remove_own
on public.favorites
for delete
to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_closetx_admin())
);

revoke all on table public.notifications from anon, authenticated;
grant select on public.notifications to authenticated;
grant update (is_read) on public.notifications to authenticated;

create policy notifications_read_recipient_or_admin
on public.notifications
for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_closetx_admin())
);

create policy notifications_mark_own_read
on public.notifications
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create or replace function public.notify_designer_of_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status
     and new.status in ('approved', 'rejected')
     and (select auth.uid()) is not null then
    insert into public.notifications (
      designer_id,
      user_id,
      design_id,
      type,
      message,
      is_read
    )
    values (
      new.designer_id,
      new.designer_id,
      new.id,
      new.status,
      case
        when new.status = 'approved' then
          'Your design "' || new.title || '" has been approved.'
        else
          'Your design "' || new.title || '" was not approved.'
      end,
      false
    );
  end if;
  return new;
end;
$$;

revoke all on function public.notify_designer_of_review() from public;
revoke all on function public.notify_designer_of_review()
  from anon, authenticated;

drop trigger if exists designs_notify_designer_of_review on public.designs;
create trigger designs_notify_designer_of_review
after update of status on public.designs
for each row execute function public.notify_designer_of_review();

commit;
