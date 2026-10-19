create table public.design_reviews (
  id uuid primary key default gen_random_uuid(),
  design_id uuid not null references public.designs (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  author_name text not null default '',
  rating integer not null check (rating between 1 and 5),
  comment text not null check (char_length(btrim(comment)) between 1 and 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (design_id, user_id)
);

create index design_reviews_design_idx
  on public.design_reviews (design_id, created_at desc);

create trigger design_reviews_set_updated_at
before update on public.design_reviews
for each row execute function public.set_updated_at();

alter table public.design_reviews enable row level security;

revoke all on table public.design_reviews from anon, authenticated;
grant select on public.design_reviews to authenticated;
grant insert (design_id, user_id, author_name, rating, comment)
  on public.design_reviews to authenticated;
grant update (author_name, rating, comment) on public.design_reviews to authenticated;

create policy design_reviews_read_published
on public.design_reviews for select to authenticated
using (
  exists (
    select 1
    from public.designs
    where designs.id = design_reviews.design_id
      and designs.is_published
  )
);

create policy design_reviews_create_own
on public.design_reviews for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.designs
    where designs.id = design_reviews.design_id
      and designs.is_published
  )
);

create policy design_reviews_update_own
on public.design_reviews for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
