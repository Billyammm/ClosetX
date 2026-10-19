begin;

alter table public.designer_application_notifications
  alter column status drop not null;

alter table public.designer_application_notifications
  add column notification_type text not null default 'application_decision'
    check (notification_type in ('application_decision', 'design_saved')),
  add column design_id uuid references public.designs (id) on delete set null,
  add column design_title text,
  add constraint designer_notifications_type_content_check
    check (
      (notification_type = 'application_decision' and status is not null)
      or (notification_type = 'design_saved' and status is null)
    );

create or replace function public.notify_designer_of_saved_design()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.designer_application_notifications (
    designer_id,
    notification_type,
    status,
    design_id,
    design_title
  )
  select
    designs.designer_id,
    'design_saved',
    null,
    designs.id,
    designs.title
  from public.designs
  where designs.id = new.design_id
    and designs.is_published
    and designs.review_status = 'approved';

  return new;
end;
$$;

revoke all on function public.notify_designer_of_saved_design() from public;
revoke all on function public.notify_designer_of_saved_design()
  from anon, authenticated;

create trigger saved_designs_notify_designer
after insert on public.saved_designs
for each row execute function public.notify_designer_of_saved_design();

commit;
