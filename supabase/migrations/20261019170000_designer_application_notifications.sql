begin;

create table public.designer_application_notifications (
  id uuid primary key default gen_random_uuid(),
  designer_id uuid not null references public.profiles (id) on delete cascade,
  status text not null check (status in ('approved', 'rejected')),
  rejection_reason text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index designer_application_notifications_owner_created_idx
  on public.designer_application_notifications (designer_id, created_at desc);

alter table public.designer_application_notifications enable row level security;

revoke all on table public.designer_application_notifications from anon, authenticated;
grant select on table public.designer_application_notifications to authenticated;
grant update (is_read) on table public.designer_application_notifications to authenticated;

create policy designer_application_notifications_read_own
on public.designer_application_notifications for select to authenticated
using (designer_id = (select auth.uid()));

create policy designer_application_notifications_mark_own_read
on public.designer_application_notifications for update to authenticated
using (designer_id = (select auth.uid()))
with check (designer_id = (select auth.uid()));

create or replace function public.notify_designer_application_decision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.role = 'designer'
     and new.role = 'designer'
     and old.designer_status is distinct from new.designer_status
     and new.designer_status in ('approved', 'rejected') then
    insert into public.designer_application_notifications (
      designer_id,
      status,
      rejection_reason,
      created_at
    )
    values (
      new.id,
      new.designer_status,
      new.designer_rejection_reason,
      coalesce(new.designer_reviewed_at, now())
    );
  end if;
  return new;
end;
$$;

revoke all on function public.notify_designer_application_decision() from public;
revoke all on function public.notify_designer_application_decision()
  from anon, authenticated;

create trigger profiles_notify_designer_application_decision
after update of designer_status on public.profiles
for each row execute function public.notify_designer_application_decision();

insert into public.designer_application_notifications (
  designer_id,
  status,
  rejection_reason,
  created_at
)
select
  profiles.id,
  profiles.designer_status,
  profiles.designer_rejection_reason,
  coalesce(profiles.designer_reviewed_at, now())
from public.profiles
where profiles.role = 'designer'
  and profiles.designer_status in ('approved', 'rejected')
  and profiles.designer_reviewed_at is not null
  and not exists (
    select 1
    from public.designer_application_notifications as notifications
    where notifications.designer_id = profiles.id
      and notifications.status = profiles.designer_status
      and notifications.created_at = profiles.designer_reviewed_at
  );

do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    raise exception 'Supabase Realtime publication does not exist.';
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'designer_application_notifications'
  ) then
    alter publication supabase_realtime
      add table public.designer_application_notifications;
  end if;
end;
$$;

commit;
