-- Dedicated, trigger-free nickname-change timestamp, same shape as dietary_updated_at
-- (008_add_dietary_updated_at.sql). Needed because profiles.updated_at is bumped by the generic
-- profiles_updated_at trigger on ANY column change, not just nickname -- using it for the 30-day
-- username cooldown meant unrelated edits (display name, avatar, allergies, etc.) silently reset
-- the cooldown, and the initial auto-assigned chef_xxxx username at signup started it immediately.
ALTER TABLE public.profiles
ADD COLUMN nickname_updated_at timestamptz;
