ALTER TABLE public.recipes
ADD COLUMN diet_type text DEFAULT 'any',
ADD COLUMN dietary_restrictions text[] DEFAULT '{}';
