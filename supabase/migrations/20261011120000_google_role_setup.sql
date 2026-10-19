create or replace function public.set_initial_google_role(new_role text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new_role not in ('shopper', 'designer') then
    raise exception 'Invalid ClosetX account role.';
  end if;

  if not exists (
    select 1
    from auth.users
    where id = (select auth.uid())
      and raw_app_meta_data ->> 'provider' = 'google'
  ) then
    raise exception 'Google account role setup is not available.';
  end if;

  update public.profiles
  set role = new_role,
      designer_status = case
        when new_role = 'designer' then 'pending'
        else 'approved'
      end
  where id = (select auth.uid())
    and role = 'shopper';
end;
$$;

revoke all on function public.set_initial_google_role(text) from public;
grant execute on function public.set_initial_google_role(text) to authenticated;
