begin;

insert into public.designer_application_notifications (
  designer_id,
  notification_type,
  status,
  rejection_reason,
  design_id,
  design_title,
  created_at
)
select
  designs.designer_id,
  'design_review_decision',
  designs.review_status,
  designs.rejection_reason,
  designs.id,
  designs.title,
  coalesce(designs.reviewed_at, designs.updated_at, designs.created_at)
from public.designs
where designs.review_status in ('approved', 'rejected')
  and designs.reviewed_at is not null
  and not exists (
    select 1
    from public.designer_application_notifications as notifications
    where notifications.design_id = designs.id
      and notifications.notification_type = 'design_review_decision'
      and notifications.status = designs.review_status
  );

commit;
