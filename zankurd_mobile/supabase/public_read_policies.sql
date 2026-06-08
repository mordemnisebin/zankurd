drop policy if exists "Anon can read active categories" on public.categories;
drop policy if exists "Anon can read approved questions" on public.questions;

create policy "Anon can read active categories"
  on public.categories for select
  to anon
  using (is_active = true);

create policy "Anon can read approved questions"
  on public.questions for select
  to anon
  using (is_approved = true);
