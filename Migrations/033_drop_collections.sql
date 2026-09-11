-- Collections feature backend removed after a persistent, unresolved 42501 on
-- collection_recipes inserts that survived a correct RLS policy, correct data, and a successful
-- hand-run insert under the same impersonated auth identity — pointing at a session/auth-identity
-- mismatch in the app's live request rather than the schema or policy. Rebuilding from scratch.
drop table if exists public.collection_recipes cascade;
drop table if exists public.collections cascade;
