-- Allow authenticated users to read any profile (needed for community reviews)
CREATE POLICY "Authenticated users can view profiles"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);
