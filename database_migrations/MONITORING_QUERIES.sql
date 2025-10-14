-- MONITORING QUERIES for HanapBuhay RLS Policies
-- Use these queries to monitor database performance and security

-- ========================================
-- SECURITY MONITORING QUERIES
-- ========================================

-- 1. Check RLS Status on All Tables
-- Run this daily to ensure all tables have RLS enabled
SELECT 
    tablename,
    CASE 
        WHEN rowsecurity THEN '✅ RLS Enabled'
        ELSE '❌ RLS Disabled - SECURITY RISK'
    END as rls_status
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

-- 2. Check for User Metadata Vulnerabilities
-- Should return 0 - any result indicates security vulnerability
SELECT 
    schemaname,
    tablename, 
    policyname,
    'VULNERABILITY FOUND' as status
FROM pg_policies
WHERE qual::text LIKE '%user_metadata%' 
   OR with_check::text LIKE '%user_metadata%'
ORDER BY tablename, policyname;

-- 3. Policy Count per Table
-- Monitor to ensure no policies are accidentally dropped
SELECT 
    tablename,
    COUNT(*) as policy_count,
    CASE 
        WHEN COUNT(*) = 0 THEN '❌ No Policies'
        WHEN COUNT(*) < 3 THEN '⚠️ Low Policy Count'
        ELSE '✅ Policies Present'
    END as status
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;

-- ========================================
-- PERFORMANCE MONITORING QUERIES
-- ========================================

-- 4. Check for Unoptimized auth.uid() Usage
-- Should return 0 for optimal performance
SELECT 
    schemaname,
    tablename,
    policyname,
    'PERFORMANCE ISSUE' as status
FROM pg_policies
WHERE qual::text LIKE '%auth.uid()%' 
   AND qual::text NOT LIKE '%(SELECT auth.uid())%'
ORDER BY tablename, policyname;

-- 5. Missing Indexes Check
-- Check for missing foreign key indexes
SELECT 
    tc.table_name,
    tc.constraint_name,
    kcu.column_name,
    CASE 
        WHEN idx.indexname IS NULL THEN '❌ Missing Index'
        ELSE '✅ Index Present'
    END as index_status
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
LEFT JOIN pg_indexes idx 
    ON idx.tablename = tc.table_name 
    AND idx.indexdef LIKE '%' || kcu.column_name || '%'
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
    AND kcu.column_name IN (
        'company_id', 'user_id', 'applicant_id', 'employer_id',
        'updated_by', 'verified_by', 'original_job_id', 'last_message_id',
        'reply_to_id', 'reviewee_id', 'reviewer_id', 'job_id'
    )
ORDER BY tc.table_name, kcu.column_name;

-- 6. Function Security Check
-- Ensure all functions have proper search_path
SELECT 
    n.nspname as schema_name,
    p.proname as function_name,
    CASE 
        WHEN p.prosecdef THEN 
            CASE 
                WHEN p.proconfig IS NULL THEN '❌ No search_path'
                WHEN array_to_string(p.proconfig, ', ') LIKE '%search_path%' THEN '✅ search_path Set'
                ELSE '⚠️ Unknown Config'
            END
        ELSE 'N/A (Not SECURITY DEFINER)'
    END as security_status
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
    AND p.prosecdef = true
ORDER BY p.proname;

-- ========================================
-- OPERATIONAL MONITORING QUERIES
-- ========================================

-- 7. Storage Bucket Status
-- Check storage bucket configuration
SELECT 
    id as bucket_name,
    public,
    file_size_limit,
    allowed_mime_types,
    CASE 
        WHEN public THEN '✅ Public Access'
        ELSE '🔒 Private Access'
    END as access_status
FROM storage.buckets
ORDER BY id;

-- 8. User Role Distribution
-- Monitor user role distribution
SELECT 
    role,
    COUNT(*) as user_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM profiles
GROUP BY role
ORDER BY user_count DESC;

-- 9. Application Status Distribution
-- Monitor job application statuses
SELECT 
    status,
    COUNT(*) as application_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM job_applications
GROUP BY status
ORDER BY application_count DESC;

-- 10. Job Status Distribution
-- Monitor job posting statuses
SELECT 
    status,
    COUNT(*) as job_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM jobs
GROUP BY status
ORDER BY job_count DESC;

-- ========================================
-- ERROR MONITORING QUERIES
-- ========================================

-- 11. Recent Login Attempts (Last 24 Hours)
-- Monitor for suspicious login activity
SELECT 
    la.identifier,
    la.success,
    COUNT(*) as attempt_count,
    MAX(la.created_at) as last_attempt
FROM login_attempts la
WHERE la.created_at >= NOW() - INTERVAL '24 hours'
GROUP BY la.identifier, la.success
ORDER BY attempt_count DESC, last_attempt DESC;

-- 12. Failed Login Attempts by User
-- Identify users with repeated failed login attempts
SELECT 
    la.identifier,
    COUNT(*) as failed_attempts,
    MIN(la.created_at) as first_attempt,
    MAX(la.created_at) as last_attempt
FROM login_attempts la
WHERE la.success = false
    AND la.created_at >= NOW() - INTERVAL '7 days'
GROUP BY la.identifier
HAVING COUNT(*) > 5
ORDER BY failed_attempts DESC;

-- 13. Audit Log Activity (Last 24 Hours)
-- Monitor system activity
SELECT 
    al.table_name,
    al.operation,
    COUNT(*) as operation_count,
    al.user_role
FROM audit_log al
WHERE al.created_at >= NOW() - INTERVAL '24 hours'
GROUP BY al.table_name, al.operation, al.user_role
ORDER BY operation_count DESC;

-- ========================================
-- PERFORMANCE ANALYSIS QUERIES
-- ========================================

-- 14. Table Size Analysis
-- Monitor table growth
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- 15. Index Usage Statistics
-- Monitor index effectiveness (requires pg_stat_user_indexes extension)
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
    AND idx_scan > 0
ORDER BY idx_scan DESC;

-- ========================================
-- DATA INTEGRITY QUERIES
-- ========================================

-- 16. Orphaned Records Check
-- Check for data integrity issues
SELECT 'job_applications without valid job' as check_type, COUNT(*) as count
FROM job_applications ja
LEFT JOIN jobs j ON j.id = ja.job_id
WHERE j.id IS NULL

UNION ALL

SELECT 'chat_members without valid chat' as check_type, COUNT(*) as count
FROM chat_members cm
LEFT JOIN chats c ON c.id = cm.chat_id
WHERE c.id IS NULL

UNION ALL

SELECT 'messages without valid chat' as check_type, COUNT(*) as count
FROM messages m
LEFT JOIN chats c ON c.id = m.chat_id
WHERE c.id IS NULL

UNION ALL

SELECT 'profiles without valid auth.users' as check_type, COUNT(*) as count
FROM profiles p
LEFT JOIN auth.users u ON u.id = p.id
WHERE u.id IS NULL;

-- 17. Duplicate Data Check
-- Check for duplicate records
SELECT 'duplicate saved_jobs' as check_type, COUNT(*) - COUNT(DISTINCT seeker_id, job_id) as duplicates
FROM saved_jobs

UNION ALL

SELECT 'duplicate chat_members' as check_type, COUNT(*) - COUNT(DISTINCT chat_id, user_id) as duplicates
FROM chat_members;

-- ========================================
-- MONITORING SCHEDULE RECOMMENDATIONS
-- ========================================

/*
DAILY MONITORING (Run these queries daily):
- Query 1: RLS Status Check
- Query 2: User Metadata Vulnerabilities
- Query 11: Recent Login Attempts
- Query 13: Audit Log Activity

WEEKLY MONITORING (Run these queries weekly):
- Query 3: Policy Count per Table
- Query 4: Unoptimized auth.uid() Usage
- Query 8: User Role Distribution
- Query 14: Table Size Analysis
- Query 16: Data Integrity Check

MONTHLY MONITORING (Run these queries monthly):
- Query 5: Missing Indexes Check
- Query 6: Function Security Check
- Query 7: Storage Bucket Status
- Query 12: Failed Login Attempts
- Query 15: Index Usage Statistics
- Query 17: Duplicate Data Check

ALERT CONDITIONS:
- Any table with RLS disabled (Query 1)
- Any user_metadata vulnerabilities found (Query 2)
- Tables with 0 policies (Query 3)
- Unoptimized auth.uid() usage (Query 4)
- Missing foreign key indexes (Query 5)
- Functions without search_path security (Query 6)
- Orphaned records found (Query 16)
- Duplicate data found (Query 17)
*/
