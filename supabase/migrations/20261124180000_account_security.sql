begin;

alter table public.profiles
  add column if not exists failed_attempts integer not null default 0
    check (failed_attempts >= 0),
  add column if not exists lockout_stage integer not null default 0
    check (lockout_stage between 0 and 3),
  add column if not exists locked_until timestamptz,
  add column if not exists is_admin_locked boolean not null default false;

create table if not exists public.password_reset_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists password_reset_tokens_user_idx
  on public.password_reset_tokens(user_id, created_at desc);

create table if not exists public.admin_notifications (
  id uuid primary key default gen_random_uuid(),
  type text not null default 'account_locked',
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null default '',
  email text,
  ip_address text,
  status text not null default 'unread'
    check (status in ('unread', 'resolved')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create unique index if not exists admin_notifications_unresolved_account_idx
  on public.admin_notifications(user_id)
  where status = 'unread';

create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid not null references auth.users(id),
  action text not null,
  target_user_id uuid references auth.users(id),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.login_ip_attempts (
  ip_address text primary key,
  failed_attempts integer not null default 0,
  window_started_at timestamptz not null default now()
);

create table if not exists public.password_reset_requests (
  ip_address text primary key,
  request_count integer not null default 0,
  window_started_at timestamptz not null default now()
);

alter table public.password_reset_tokens enable row level security;
alter table public.admin_notifications enable row level security;
alter table public.admin_audit_log enable row level security;
alter table public.login_ip_attempts enable row level security;
alter table public.password_reset_requests enable row level security;

create or replace function public.check_login_lockout(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p public.profiles%rowtype;
  remaining integer;
begin
  select * into p from public.profiles where id = p_user_id for update;
  if not found then
    return jsonb_build_object('allowed', true);
  end if;
  if p.is_admin_locked then
    return jsonb_build_object('allowed', false, 'adminLocked', true);
  end if;
  if p.locked_until is not null and p.locked_until > now() then
    remaining := greatest(1, ceil(extract(epoch from (p.locked_until - now())))::integer);
    return jsonb_build_object('allowed', false, 'remainingSeconds', remaining,
      'stage', p.lockout_stage);
  end if;
  if p.locked_until is not null and p.locked_until <= now() then
    update public.profiles
      set locked_until = null
      where id = p_user_id;
  end if;
  return jsonb_build_object('allowed', true, 'failedAttempts', p.failed_attempts,
    'stage', p.lockout_stage);
end;
$$;

revoke all on function public.check_login_lockout(uuid) from public, anon, authenticated;

create or replace function public.record_login_failure(p_user_id uuid, p_ip text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p public.profiles%rowtype;
  new_attempts integer;
  new_stage integer;
  lock_seconds integer;
  remaining integer;
begin
  select * into p from public.profiles where id = p_user_id for update;
  if not found then
    return jsonb_build_object('locked', false, 'failedAttempts', 0);
  end if;
  if p.is_admin_locked then
    return jsonb_build_object('locked', true, 'adminLocked', true);
  end if;
  if p.locked_until is not null and p.locked_until > now() then
    remaining := greatest(1, ceil(extract(epoch from (p.locked_until - now())))::integer);
    return jsonb_build_object('locked', true, 'remainingSeconds', remaining,
      'stage', p.lockout_stage);
  end if;

  new_attempts := p.failed_attempts + 1;
  new_stage := p.lockout_stage;

  if new_attempts >= 3 then
    new_attempts := 0;
    if p.lockout_stage = 0 then
      new_stage := 1;
      lock_seconds := 30;
    elsif p.lockout_stage = 1 then
      new_stage := 2;
      lock_seconds := 60;
    else
      new_stage := 3;
      update public.profiles
        set is_admin_locked = true,
            failed_attempts = 0,
            lockout_stage = 3,
            locked_until = null
        where id = p_user_id;

      insert into public.admin_notifications (
        type, user_id, username, email, ip_address, status
      )
      select 'account_locked', p.id,
             split_part(coalesce(u.email, ''), '@', 1),
             u.email, p_ip, 'unread'
      from auth.users u
      where u.id = p_user_id
      on conflict do nothing;

      return jsonb_build_object('locked', true, 'adminLocked', true);
    end if;

    update public.profiles
      set failed_attempts = 0,
          lockout_stage = new_stage,
          locked_until = now() + make_interval(secs => lock_seconds)
      where id = p_user_id;
    return jsonb_build_object('locked', true, 'remainingSeconds', lock_seconds,
      'stage', new_stage);
  end if;

  update public.profiles set failed_attempts = new_attempts where id = p_user_id;
  return jsonb_build_object(
    'locked', false,
    'failedAttempts', new_attempts,
    'attemptsLeft', 3 - new_attempts,
    'nextLockSeconds', case when new_stage = 0 then 30 when new_stage = 1 then 60 else 60 end,
    'stage', new_stage
  );
end;
$$;

revoke all on function public.record_login_failure(uuid, text) from public, anon, authenticated;

create or replace function public.reset_login_lockout(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
    set failed_attempts = 0,
        lockout_stage = 0,
        locked_until = null
    where id = p_user_id;
end;
$$;

revoke all on function public.reset_login_lockout(uuid) from public, anon, authenticated;

create or replace function public.admin_unlock_account(p_target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_closetx_admin() then
    raise exception 'Only a ClosetX administrator can unlock accounts.';
  end if;

  update public.profiles
    set is_admin_locked = false,
        failed_attempts = 0,
        lockout_stage = 0,
        locked_until = null
    where id = p_target_user_id;

  update public.admin_notifications
    set status = 'resolved', resolved_at = now()
    where user_id = p_target_user_id and status = 'unread';

  insert into public.admin_audit_log (
    admin_user_id, action, target_user_id, details
  ) values (
    auth.uid(), 'unlock_account', p_target_user_id,
    jsonb_build_object('unlocked_at', now())
  );
end;
$$;

revoke all on function public.admin_unlock_account(uuid) from public;
grant execute on function public.admin_unlock_account(uuid) to authenticated;

create policy admin_notifications_admin_all
on public.admin_notifications for all to authenticated
using ((select public.is_closetx_admin()))
with check ((select public.is_closetx_admin()));

create policy admin_audit_log_admin_read
on public.admin_audit_log for select to authenticated
using ((select public.is_closetx_admin()));

commit;
