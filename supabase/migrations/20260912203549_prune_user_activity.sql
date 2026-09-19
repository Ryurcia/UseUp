create extension if not exists pg_cron with schema extensions;

select cron.schedule(
  'prune-user-activity',
  '0 3 * * *', -- daily at 03:00 UTC
  $$ delete from public.user_activity where created_at < now() - interval '90 days'; $$
);
