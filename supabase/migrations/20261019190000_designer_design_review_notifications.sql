begin;

alter table public.designs disable trigger designs_protect_closetx_review;

update public.designs
set is_published = false
where review_status = 'rejected'
  and is_published;

alter table public.designs enable trigger designs_protect_closetx_review;

alter table public.designs
  add constraint rejected_designs_are_unpublished
    check (review_status <> 'rejected' or not is_published);

alter table public.designer_application_notifications
  drop constraint designer_application_notifications_notification_type_check,
  add constraint designer_application_notifications_notification_type_check
    check (
      notification_type in (
        'application_decision',
        'design_saved',
        'design_review_decision'
      )
    ),
  drop constraint designer_notifications_type_content_check,
  add constraint designer_notifications_type_content_check
    check (
      (notification_type = 'application_decision' and status is not null)
      or (notification_type = 'design_saved' and status is null)
      or (
        notification_type = 'design_review_decision'
        and status is not null
        and status in ('approved', 'rejected')
      )
    );

create or replace function public.notify_designer_of_design_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.review_status is distinct from new.review_status
     and new.review_status in ('approved', 'rejected') then
    insert into public.designer_application_notifications (
      designer_id,
      notification_type,
      status,
      rejection_reason,
      design_id,
      design_title
    )
    values (
      new.designer_id,
      'design_review_decision',
      new.review_status,
      new.rejection_reason,
      new.id,
      new.title
    );
  end if;

  return new;
end;
$$;

revoke all on function public.notify_designer_of_design_review() from public;
revoke all on function public.notify_designer_of_design_review()
  from anon, authenticated;

create trigger designs_notify_designer_of_review
after update of review_status on public.designs
for each row execute function public.notify_designer_of_design_review();

commit;
