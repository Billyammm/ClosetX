begin;

alter table public.designer_profiles
  add column if not exists application_status text not null default 'pending',
  add column if not exists application_rejection_reason text;

update public.designer_profiles
set application_status = case
  when is_verified is true then 'approved'
  else 'pending'
end
where application_status is null
   or application_status not in ('pending', 'approved', 'rejected');

alter table public.designer_profiles
  drop constraint if exists designer_profiles_application_status_check;
alter table public.designer_profiles
  add constraint designer_profiles_application_status_check
  check (application_status in ('pending', 'approved', 'rejected'));
alter table public.designer_profiles
  drop constraint if exists designer_profiles_application_verification_check;
alter table public.designer_profiles
  add constraint designer_profiles_application_verification_check
  check ((application_status = 'approved') = (is_verified is true));
alter table public.designer_profiles
  drop constraint if exists designer_profiles_application_rejection_reason_check;
alter table public.designer_profiles
  add constraint designer_profiles_application_rejection_reason_check
  check (
    application_status = 'rejected'
    or nullif(btrim(application_rejection_reason), '') is null
  );

create index if not exists designer_profiles_application_review_idx
  on public.designer_profiles (application_status, created_at desc);

update public.designer_profiles
set application_status = 'approved'
where is_verified is true;
update public.designer_profiles
set application_status = 'pending',
    application_rejection_reason = null
where is_verified is not true
  and application_status = 'approved';
update public.designer_profiles
set application_rejection_reason = null
where application_status <> 'rejected';
update public.designer_profiles
set application_rejection_reason = 'Application declined previously.'
where application_status = 'rejected'
  and nullif(btrim(application_rejection_reason), '') is null;

create or replace function public.guard_designer_verification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (
    new.is_verified is distinct from old.is_verified
    or new.application_status is distinct from old.application_status
    or new.application_rejection_reason is distinct from old.application_rejection_reason
  ) and not (select public.is_closetx_admin()) then
    raise exception 'Only an admin can review designer applications.';
  end if;

  return new;
end;
$$;

grant update (
  is_verified,
  application_status,
  application_rejection_reason
) on public.designer_profiles to authenticated;

drop policy if exists designs_create_pending_for_designer on public.designs;
create policy designs_create_pending_for_approved_designer
on public.designs
for insert
to authenticated
with check (
  designer_id = (select auth.uid())
  and (select public.is_closetx_designer())
  and status = 'pending'
  and exists (
    select 1
    from public.designer_profiles
    where designer_profiles.user_id = (select auth.uid())
      and designer_profiles.application_status = 'approved'
      and designer_profiles.is_verified is true
  )
);

drop policy if exists designers_update_own_unapproved_designs on public.designs;
create policy designers_update_own_unapproved_designs
on public.designs
for update
to authenticated
using (
  designer_id = (select auth.uid())
  and (select public.is_closetx_designer())
  and status in ('pending', 'rejected')
  and exists (
    select 1
    from public.designer_profiles
    where designer_profiles.user_id = (select auth.uid())
      and designer_profiles.application_status = 'approved'
      and designer_profiles.is_verified is true
  )
)
with check (
  designer_id = (select auth.uid())
  and (select public.is_closetx_designer())
  and status in ('pending', 'rejected')
  and exists (
    select 1
    from public.designer_profiles
    where designer_profiles.user_id = (select auth.uid())
      and designer_profiles.application_status = 'approved'
      and designer_profiles.is_verified is true
  )
);

commit;
