-- Case-insensitive uniqueness for profiles.nickname (the app's "username"/handle field).
-- Pre-flight check before applying in production -- this migration will fail if any duplicates
-- exist (expected to be none in practice, but not backfilled/verified here; existing accounts
-- were deliberately left untouched):
--   SELECT lower(nickname), count(*) FROM public.profiles
--   WHERE nickname IS NOT NULL GROUP BY lower(nickname) HAVING count(*) > 1;
CREATE UNIQUE INDEX IF NOT EXISTS profiles_nickname_lower_unique_idx
  ON public.profiles (lower(nickname))
  WHERE nickname IS NOT NULL;
