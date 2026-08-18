-- Enum for report categories
create type report_category as enum (
  'spam',
  'harassment',
  'hate_speech',
  'violence',
  'self_harm',
  'nudity'
);

-- Reports table
create table recipe_reports (
  id           uuid primary key default gen_random_uuid(),
  recipe_id    uuid not null references recipes(id) on delete cascade,
  reporter_id  uuid not null references auth.users(id) on delete cascade,
  category     report_category not null,
  description  text,
  created_at   timestamptz not null default now()
);

-- Prevent a user from submitting duplicate reports for the same recipe
alter table recipe_reports
  add constraint recipe_reports_reporter_recipe_unique unique (reporter_id, recipe_id);

-- RLS
alter table recipe_reports enable row level security;

-- Users can submit a report (only for their own reporter_id)
create policy "Users can insert their own reports"
  on recipe_reports for insert
  to authenticated
  with check (auth.uid() = reporter_id);

-- Users can view only their own reports
create policy "Users can view their own reports"
  on recipe_reports for select
  to authenticated
  using (auth.uid() = reporter_id);
