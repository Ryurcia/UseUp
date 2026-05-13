ALTER TABLE public.profiles
ADD COLUMN subscription_type text NOT NULL DEFAULT 'free';
