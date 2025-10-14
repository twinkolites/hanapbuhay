-- ROLLBACK SCRIPTS for HanapBuhay RLS Policies
-- Use these scripts only if critical issues are found during testing
-- WARNING: These scripts will revert all security improvements

-- IMPORTANT: Always backup your data before running rollback scripts
-- These scripts are designed to be run in order if needed

-- ========================================
-- ROLLBACK PHASE 8: Function Security
-- ========================================

-- Remove search_path security from functions
BEGIN;

ALTER FUNCTION public.check_time_slot_availability(uuid, timestamp with time zone, timestamp with time zone)
  RESET search_path;

ALTER FUNCTION public.send_message(uuid, uuid, text, text, uuid)
  RESET search_path;

ALTER FUNCTION public.mark_messages_read(uuid, uuid)
  RESET search_path;

ALTER FUNCTION public.get_available_time_slots(uuid, date, integer)
  RESET search_path;

ALTER FUNCTION public.expire_old_meeting_requests()
  RESET search_path;

ALTER FUNCTION public.get_employer_profile_data(uuid)
  RESET search_path;

ALTER FUNCTION public.create_event_from_meeting_request(uuid)
  RESET search_path;

ALTER FUNCTION public.get_applicant_profile_stats(uuid)
  RESET search_path;

ALTER FUNCTION public.is_user_chat_member(uuid, uuid)
  RESET search_path;

ALTER FUNCTION public.update_application_status(uuid, text, uuid)
  RESET search_path;

ALTER FUNCTION public.update_application_status(uuid, app_status, uuid, timestamp with time zone, text, integer)
  RESET search_path;

ALTER FUNCTION public.get_pending_employer_approvals()
  RESET search_path;

ALTER FUNCTION public.mark_chat_messages_read(uuid, uuid)
  RESET search_path;

ALTER FUNCTION public.create_or_get_chat(uuid, uuid, uuid)
  RESET search_path;

ALTER FUNCTION public.update_chat_last_message()
  RESET search_path;

ALTER FUNCTION public.restore_archived_job(uuid)
  RESET search_path;

ALTER FUNCTION public.get_chat_messages(uuid, integer, integer)
  RESET search_path;

ALTER FUNCTION public.archive_job(uuid)
  RESET search_path;

ALTER FUNCTION public.get_user_chats(uuid)
  RESET search_path;

ALTER FUNCTION public.get_user_unread_count(uuid)
  RESET search_path;

ALTER FUNCTION public.handle_new_user()
  RESET search_path;

COMMIT;

-- ========================================
-- ROLLBACK PHASE 7: Foreign Key Indexes
-- ========================================

-- Drop performance indexes (only if causing issues)
BEGIN;

DROP INDEX IF EXISTS idx_ai_screening_criteria_company_id;
DROP INDEX IF EXISTS idx_ai_screening_results_applicant_id;
DROP INDEX IF EXISTS idx_application_tracking_updated_by;
DROP INDEX IF EXISTS idx_archived_jobs_original_job_id;
DROP INDEX IF EXISTS idx_audit_log_user_id;
DROP INDEX IF EXISTS idx_calendar_events_job_id;
DROP INDEX IF EXISTS idx_chats_last_message_id;
DROP INDEX IF EXISTS idx_company_details_company_id;
DROP INDEX IF EXISTS idx_employer_verification_company_id;
DROP INDEX IF EXISTS idx_employer_verification_employer_id;
DROP INDEX IF EXISTS idx_employer_verification_verified_by;
DROP INDEX IF EXISTS idx_login_attempts_user_id;
DROP INDEX IF EXISTS idx_meeting_requests_job_id;
DROP INDEX IF EXISTS idx_messages_reply_to_id;
DROP INDEX IF EXISTS idx_reviews_reviewee_id;
DROP INDEX IF EXISTS idx_reviews_reviewer_id;
DROP INDEX IF EXISTS idx_saved_jobs_job_id;
DROP INDEX IF EXISTS idx_typing_indicators_user_id;

COMMIT;

-- ========================================
-- ROLLBACK PHASE 6: Performance Optimization
-- ========================================

-- Revert auth.uid() optimizations (only if causing issues)
-- Note: This reverts to less performant but potentially more compatible version

BEGIN;

-- Revert profiles table policies
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
CREATE POLICY "Users can view own profile"
ON profiles FOR SELECT TO authenticated
USING (id = auth.uid());

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE TO authenticated
USING (id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile"
ON profiles FOR INSERT TO authenticated
WITH CHECK (id = auth.uid());

-- Revert job_applications table policies
DROP POLICY IF EXISTS "Applicants can view their own applications" ON job_applications;
CREATE POLICY "Applicants can view their own applications"
ON job_applications FOR SELECT TO authenticated
USING (applicant_id = auth.uid());

DROP POLICY IF EXISTS "Applicants can create applications" ON job_applications;
CREATE POLICY "Applicants can create applications"
ON job_applications FOR INSERT TO authenticated
WITH CHECK (applicant_id = auth.uid());

-- Revert saved_jobs table policies
DROP POLICY IF EXISTS "Users can manage their saved jobs" ON saved_jobs;
CREATE POLICY "Users can manage their saved jobs"
ON saved_jobs FOR ALL TO authenticated
USING (seeker_id = auth.uid());

-- Revert companies table policies
DROP POLICY IF EXISTS "Company owners can manage their companies" ON companies;
CREATE POLICY "Company owners can manage their companies"
ON companies FOR ALL TO authenticated
USING (owner_id = auth.uid());

DROP POLICY IF EXISTS "Authenticated users can insert companies" ON companies;
CREATE POLICY "Authenticated users can insert companies"
ON companies FOR INSERT TO authenticated
WITH CHECK (owner_id = auth.uid());

COMMIT;

-- ========================================
-- ROLLBACK PHASE 5: Bookmarks Policies
-- ========================================

-- Note: Phase 5 policies were already present, so no rollback needed

-- ========================================
-- ROLLBACK PHASE 4: Storage Policies
-- ========================================

-- Note: Storage policies are managed by Supabase and may not be easily rollbackable
-- The company-logos bucket can be removed if needed:

-- Remove company-logos bucket (if causing issues)
-- DELETE FROM storage.buckets WHERE id = 'company-logos';

-- ========================================
-- ROLLBACK PHASE 3: Withdraw Functionality
-- ========================================

BEGIN;

-- Remove withdrawal policies
DROP POLICY IF EXISTS "Applicants can withdraw own applications" ON job_applications;
DROP POLICY IF EXISTS "Applicants can track withdrawals" ON application_tracking;

COMMIT;

-- ========================================
-- ROLLBACK PHASE 2: User Metadata Security
-- ========================================

-- WARNING: This reverts to insecure user_metadata checks
-- Only use if absolutely necessary and plan to fix immediately

BEGIN;

-- Revert to insecure user_metadata checks (NOT RECOMMENDED)
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
CREATE POLICY "Admins can view all profiles"
ON profiles FOR SELECT TO authenticated
USING (((auth.jwt() ->> 'user_metadata')::jsonb ->> 'role') = 'admin');

DROP POLICY IF EXISTS "Admins can view all companies" ON companies;
CREATE POLICY "Admins can view all companies"
ON companies FOR SELECT TO authenticated
USING (((auth.jwt() ->> 'user_metadata')::jsonb ->> 'role') = 'admin');

DROP POLICY IF EXISTS "Admins can view all applicant profiles" ON applicant_profile;
CREATE POLICY "Admins can view all applicant profiles"
ON applicant_profile FOR SELECT TO authenticated
USING (((auth.jwt() ->> 'user_metadata')::jsonb ->> 'role') = 'admin');

COMMIT;

-- ========================================
-- ROLLBACK PHASE 1: Enable RLS
-- ========================================

-- WARNING: This removes RLS protection from critical tables
-- Only use if absolutely necessary

BEGIN;

-- Remove policies from unprotected tables
DROP POLICY IF EXISTS "Admins can view audit logs" ON audit_log;
DROP POLICY IF EXISTS "System can insert audit logs" ON audit_log;

DROP POLICY IF EXISTS "Users can view own login attempts" ON login_attempts;
DROP POLICY IF EXISTS "Admins can view all login attempts" ON login_attempts;
DROP POLICY IF EXISTS "System can insert login attempts" ON login_attempts;

DROP POLICY IF EXISTS "Chat members can view typing indicators" ON typing_indicators;
DROP POLICY IF EXISTS "Chat members can manage typing status" ON typing_indicators;

-- Disable RLS on tables (NOT RECOMMENDED)
-- ALTER TABLE audit_log DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE login_attempts DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE typing_indicators DISABLE ROW LEVEL SECURITY;

COMMIT;

-- ========================================
-- VERIFICATION QUERIES
-- ========================================

-- Check RLS status after rollback
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('audit_log', 'login_attempts', 'typing_indicators')
ORDER BY tablename;

-- Check for user_metadata vulnerabilities (should return 3 if rolled back)
SELECT COUNT(*) as user_metadata_policies_count
FROM pg_policies
WHERE qual::text LIKE '%user_metadata%' 
   OR with_check::text LIKE '%user_metadata%';

-- Check performance optimization status (should return many if rolled back)
SELECT COUNT(*) as unoptimized_policies_count
FROM pg_policies
WHERE qual::text LIKE '%auth.uid()%' 
   AND qual::text NOT LIKE '%(SELECT auth.uid())%';

-- ========================================
-- IMPORTANT NOTES
-- ========================================

/*
ROLLBACK INSTRUCTIONS:

1. Only run rollback scripts if critical issues are found during testing
2. Run scripts in order (Phase 8 → Phase 1)
3. Test each phase rollback before proceeding to next
4. Document any issues found during rollback
5. Plan to re-implement fixes as soon as possible

SECURITY WARNING:
Rolling back these changes will:
- Remove RLS protection from audit_log, login_attempts, typing_indicators
- Revert to insecure user_metadata checks
- Remove performance optimizations
- Remove foreign key indexes
- Remove function security improvements

These rollbacks should be temporary and fixes should be re-implemented immediately.

CONTACT:
If you need to rollback, contact the development team immediately to:
1. Understand the root cause of issues
2. Plan a proper fix
3. Re-implement security improvements
*/
