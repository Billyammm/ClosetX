grant update (author_name, rating, comment)
on table public.design_reviews
to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'design_reviews'
      and policyname = 'design_reviews_update_own'
  ) then
    create policy design_reviews_update_own
    on public.design_reviews for update to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));
  end if;
end;
$$;
