-- User reports table
-- Uses existing report_category enum from 019_recipe_reports.sql

create table user_reports (
  id                uuid primary key default gen_random_uuid(),
  reported_user_id  uuid not null references auth.users(id) on delete cascade,
  reporter_id       uuid not null references auth.users(id) on delete cascade,
  category          report_category not null,
  description       text,
  created_at        timestamptz not null default now()
);

-- Prevent a user from submitting duplicate reports for the same user
alter table user_reports
  add constraint user_reports_unique unique (reporter_id, reported_user_id);

-- RLS
alter table user_reports enable row level security;

create policy "Users can insert their own user reports"
  on user_reports for insert
  to authenticated
  with check (auth.uid() = reporter_id);

create policy "Users can view their own user reports"
  on user_reports for select
  to authenticated
  using (auth.uid() = reporter_id);
