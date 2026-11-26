begin;

create or replace function public.admin_bulk_set_design_shirt_colors(p_updates jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  update_item jsonb;
  updated_count integer := 0;
begin
  if not public.is_closetx_admin() then
    raise exception 'Only a ClosetX administrator can update design shirt colors.';
  end if;
  if jsonb_typeof(p_updates) is distinct from 'array' then
    raise exception 'A list of design colors is required.';
  end if;
  if jsonb_array_length(p_updates) > 5000 then
    raise exception 'A maximum of 5000 designs can be updated at once.';
  end if;

  for update_item in
    select value from jsonb_array_elements(p_updates) as updates(value)
  loop
    if jsonb_typeof(update_item) is distinct from 'object'
       or coalesce(update_item ->> 'id', '') !~*
         '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise exception 'Every design update must include a valid design ID.';
    end if;
    if coalesce(update_item ->> 'color', '') !~ '^#[0-9A-Fa-f]{6}$' then
      raise exception 'Every shirt color must use #RRGGBB format.';
    end if;

    update public.designs
      set shirt_color = update_item ->> 'color'
      where id = (update_item ->> 'id')::uuid;
    if not found then
      raise exception 'A design in the color update list no longer exists.';
    end if;
    updated_count := updated_count + 1;
  end loop;

  return updated_count;
end;
$$;

revoke all on function public.admin_bulk_set_design_shirt_colors(jsonb)
  from public, anon;
grant execute on function public.admin_bulk_set_design_shirt_colors(jsonb)
  to authenticated;

commit;
