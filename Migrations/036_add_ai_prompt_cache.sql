-- Tracks the Gemini `cachedContents` resource that holds the recipe-generation system prompt, so
-- the `generate-recipes` edge function can reuse one project-wide explicit cache across all users
-- instead of re-sending (and re-billing) the ~1.2K-token system prompt on every call. One row per
-- (model, prompt-hash); the function refreshes it when it's within 30 min of expiry.
--
-- No RLS policies on purpose: only the edge function (service role, which bypasses RLS) ever
-- touches this table. Clients have no reason to read or write it.
create table public.ai_prompt_cache (
  id           text primary key,          -- '<model>:<prompt_hash>', e.g. 'models/gemini-2.5-flash:1a2b3c4d5e6f'
  cache_name   text        not null,      -- Gemini resource name, e.g. 'cachedContents/xxxxxxxx'
  model        text        not null,
  prompt_hash  text        not null,
  token_count  integer,
  expires_at   timestamptz not null,
  updated_at   timestamptz not null default now()
);

alter table public.ai_prompt_cache enable row level security;
