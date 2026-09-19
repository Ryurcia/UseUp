-- Feedback submissions table — one table for both "Report a Bug" and "Request a Feature"
-- (distinguished by the `kind` column), backing the Get Help screen.

create type feedback_kind as enum ('bug', 'feature');

create table feedback_submissions (
  id           uuid primary key default gen_random_uuid(),
  reporter_id  uuid not null references auth.users(id) on delete cascade,
  kind         feedback_kind not null,
  description  text not null,
  created_at   timestamptz not null default now()
);

-- RLS
alter table feedback_submissions enable row level security;

create policy "Users can insert their own feedback"
  on feedback_submissions for insert
  to authenticated
  with check (auth.uid() = reporter_id);

create policy "Users can view their own feedback"
  on feedback_submissions for select
  to authenticated
  using (auth.uid() = reporter_id);
