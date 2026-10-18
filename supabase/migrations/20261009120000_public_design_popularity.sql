begin;

create or replace function public.get_published_design_save_counts()
returns table (design_id uuid, save_count bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select designs.id, count(saved_designs.shopper_id)
  from public.designs
  left join public.saved_designs
    on saved_designs.design_id = designs.id
  where designs.is_published
    and designs.review_status = 'approved'
  group by designs.id;
$$;

revoke all on function public.get_published_design_save_counts() from public;
grant execute on function public.get_published_design_save_counts()
  to anon, authenticated;

commit;
