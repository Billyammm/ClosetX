begin;

create table public.saved_designs (
  design_id uuid not null references public.designs (id) on delete cascade,
  shopper_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (design_id, shopper_id)
);

create index saved_designs_shopper_idx
  on public.saved_designs (shopper_id, created_at desc);

alter table public.saved_designs enable row level security;
revoke all on table public.saved_designs from anon, authenticated;
grant select, insert, delete on table public.saved_designs to authenticated;

create policy saved_designs_read_own_or_admin
on public.saved_designs for select to authenticated
using (
  shopper_id = (select auth.uid())
  or (select public.is_closetx_admin())
);

create policy saved_designs_create_own
on public.saved_designs for insert to authenticated
with check (
  shopper_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles
    where profiles.id = (select auth.uid())
      and profiles.role = 'shopper'
  )
  and exists (
    select 1
    from public.designs
    where designs.id = saved_designs.design_id
      and designs.is_published
      and designs.review_status = 'approved'
  )
);

create policy saved_designs_remove_own
on public.saved_designs for delete to authenticated
using (shopper_id = (select auth.uid()));

create or replace function public.get_design_save_counts()
returns table (design_id uuid, save_count bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_closetx_admin()
     and not public.is_closetx_designer() then
    raise exception 'Only designers and admins can view save counts.';
  end if;

  return query
  select designs.id, count(saved_designs.shopper_id)
  from public.designs
  left join public.saved_designs
    on saved_designs.design_id = designs.id
  where public.is_closetx_admin()
     or designs.designer_id = (select auth.uid())
  group by designs.id;
end;
$$;

revoke all on function public.get_design_save_counts() from public;
grant execute on function public.get_design_save_counts() to authenticated;

commit;
