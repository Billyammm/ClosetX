grant select on public.design_reviews to anon;

create policy design_reviews_read_published_anon
on public.design_reviews for select to anon
using (
  exists (
    select 1
    from public.designs
    where designs.id = design_reviews.design_id
      and designs.is_published
  )
);
