-- Close exploit: users could directly PATCH subscription_type = 'premium' via REST API.
-- The WITH CHECK subquery ensures the new value must equal the current value,
-- making subscription_type immutable for client writes.
-- The revenuecat-webhook Edge Function uses the service role key, which bypasses RLS entirely.

drop policy "Users can update own profile" on public.profiles;

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (
    auth.uid() = id
    AND subscription_type = (
      select subscription_type from public.profiles where id = auth.uid()
    )
  );
