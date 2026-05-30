-- 1) Tighten profile_monthly_points: remove anon/public broad SELECT.
-- Leaderboard uses get_leaderboard() SECURITY DEFINER which bypasses RLS, so UI is unaffected.
DROP POLICY IF EXISTS "allow anon select monthly points" ON public.profile_monthly_points;
DROP POLICY IF EXISTS "enable read access for all users" ON public.profile_monthly_points;

-- Keep the existing "users can view own monthly points" policy (already present).

-- 2) Private 'images' bucket: explicit deny for non-service-role.
-- Service role bypasses RLS, so the external scraper continues to work.
DROP POLICY IF EXISTS "Block client read on images bucket" ON storage.objects;
CREATE POLICY "Block client read on images bucket"
ON storage.objects
FOR SELECT
TO authenticated, anon
USING (bucket_id <> 'images');

DROP POLICY IF EXISTS "Block client write on images bucket" ON storage.objects;
CREATE POLICY "Block client write on images bucket"
ON storage.objects
FOR INSERT
TO authenticated, anon
WITH CHECK (bucket_id <> 'images');

DROP POLICY IF EXISTS "Block client update on images bucket" ON storage.objects;
CREATE POLICY "Block client update on images bucket"
ON storage.objects
FOR UPDATE
TO authenticated, anon
USING (bucket_id <> 'images');

DROP POLICY IF EXISTS "Block client delete on images bucket" ON storage.objects;
CREATE POLICY "Block client delete on images bucket"
ON storage.objects
FOR DELETE
TO authenticated, anon
USING (bucket_id <> 'images');

-- 3) Lock search_path on functions missing it (linter fix, no behavior change).
-- Some historical functions are not part of this challenge export, so guard each ALTER.
DO $$
DECLARE
  fn regprocedure;
BEGIN
  FOREACH fn IN ARRAY ARRAY[
    to_regprocedure('public.setup_cron_extensions()'),
    to_regprocedure('public.get_week_start(date)'),
    to_regprocedure('public.ensure_user_streak(uuid)'),
    to_regprocedure('public.handle_updated_at()'),
    to_regprocedure('public.create_publish_posts_cron_job()'),
    to_regprocedure('public.trigger_daily_streak_checker()'),
    to_regprocedure('public.schedule_linkedin_token_maintenance()'),
    to_regprocedure('public.enable_push_notifications(uuid)'),
    to_regprocedure('public.disable_push_notifications(uuid)'),
    to_regprocedure('public.get_push_registration_status(uuid)'),
    to_regprocedure('public."trigger-fetch-ses-news"()'),
    to_regprocedure('public.trigger_publish_scheduled_posts()'),
    to_regprocedure('public.publish_scheduled_posts()'),
    to_regprocedure('public.trigger_delete_old_articles()'),
    to_regprocedure('public.ensure_user_goal(uuid)'),
    to_regprocedure('public.touch_updated_at()'),
    to_regprocedure('public.update_profile_current_month_points()'),
    to_regprocedure('public.trigger_extract_sources()'),
    to_regprocedure('public.trigger_specialized_fetch()'),
    to_regprocedure('public.schedule_publish_posts_cron()'),
    to_regprocedure('public.trigger_fetch_trusted_articles()')
  ] LOOP
    IF fn IS NOT NULL THEN
      EXECUTE format('ALTER FUNCTION %s SET search_path = public', fn);
    END IF;
  END LOOP;
END $$;
