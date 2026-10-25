begin;

alter table public.designs
  add column front_print_scale real not null default 1
    check (front_print_scale between 0.5 and 2),
  add column front_print_offset_x real not null default 0
    check (front_print_offset_x between -0.5 and 0.5),
  add column front_print_offset_y real not null default 0
    check (front_print_offset_y between -0.5 and 0.5),
  add column back_print_scale real not null default 1
    check (back_print_scale between 0.5 and 2),
  add column back_print_offset_x real not null default 0
    check (back_print_offset_x between -0.5 and 0.5),
  add column back_print_offset_y real not null default 0
    check (back_print_offset_y between -0.5 and 0.5);

grant insert (
  front_print_scale,
  front_print_offset_x,
  front_print_offset_y,
  back_print_scale,
  back_print_offset_x,
  back_print_offset_y
) on public.designs to authenticated;

commit;
