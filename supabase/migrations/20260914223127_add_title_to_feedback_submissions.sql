-- Report a Bug / Request a Feature now collect a short title alongside the description.
alter table feedback_submissions
  add column title text not null default '';

alter table feedback_submissions
  alter column title drop default;
