ALTER TABLE public.profiles
ADD COLUMN dietary_preference text DEFAULT 'any';

ALTER TABLE public.profiles
ADD COLUMN dietary_restrictions text;
