
-- Step 1: normalise existing negatives
UPDATE public.profiles
SET    current_month_points = 0
WHERE  current_month_points < 0;

-- Step 2: enforce at the database level
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_current_month_points_non_negative
  CHECK (current_month_points >= 0)
  NOT VALID;

ALTER TABLE public.profiles
  VALIDATE CONSTRAINT profiles_current_month_points_non_negative;
