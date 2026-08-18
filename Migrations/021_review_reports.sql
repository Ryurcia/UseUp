-- Review reports table
-- Uses existing report_category enum from 019_recipe_reports.sql

create table review_reports (
  id               uuid primary key default gen_random_uuid(),
  recipe_id        uuid not null references recipes(id) on delete cascade,
  reviewer_user_id uuid not null references auth.users(id) on delete cascade,
  reporter_id      uuid not null references auth.users(id) on delete cascade,
  category         report_category not null,
  description      text,
  created_at       timestamptz not null default now()
);

-- Prevent a user from submitting duplicate reports for the same review
alter table review_reports
  add constraint review_reports_unique
  unique (reporter_id, reviewer_user_id, recipe_id);

-- RLS
alter table review_reports enable row level security;

create policy "Users can insert their own review reports"
  on review_reports for insert
  to authenticated
  with check (auth.uid() = reporter_id);

create policy "Users can view their own review reports"
  on review_reports for select
  to authenticated
  using (auth.uid() = reporter_id);
