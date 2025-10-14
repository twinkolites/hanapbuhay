# HanapBuhay RLS Testing Checklist

## Overview
This checklist provides comprehensive testing procedures for all UI functionality that depends on Row Level Security policies. **IMPORTANT**: This testing must be performed manually with a Flutter emulator or physical device after all database changes are complete.

## Prerequisites
- ✅ All database migrations applied (Phases 1-8 completed)
- ✅ Flutter app running: `flutter run`
- ✅ Test accounts available (applicant, employer, admin roles)

## Phase 9: Manual UI Testing

### 1. Withdraw Button Test
**Purpose**: Verify job application withdrawal functionality works without RLS errors.

**Steps**:
1. Login as an applicant
2. Navigate to "My Applications" screen
3. Find an application with status 'applied' or 'under_review'
4. Click "Withdraw" button
5. Select a withdrawal reason from the dropdown
6. Click "Confirm Withdrawal"
7. **Expected Result**: 
   - Application status changes to 'withdrawn'
   - No RLS permission errors in console
   - Withdrawal tracking entry created
   - Notification sent to employer

**Verification Query**:
```sql
SELECT status, withdrawal_reason, withdrawn_at 
FROM job_applications 
WHERE id = 'application_id_here';
```

### 2. Filter Button Test
**Purpose**: Verify job filtering works without RLS errors.

**Steps**:
1. Navigate to Jobs Screen
2. Click the filter button (funnel icon)
3. Apply multiple filters:
   - Job Type: "Full Time"
   - Location: "Manila"
   - Experience: "Mid Level"
   - Salary Range: ₱30,000 - ₱50,000
   - Industry: "Technology"
4. Click "Apply Filters"
5. **Expected Result**:
   - Filtered results display correctly
   - No RLS permission errors
   - All visible jobs match filter criteria
   - Jobs from different companies visible (public access)

**Test Multiple Scenarios**:
- Clear all filters
- Apply single filter
- Apply multiple filters
- Test search query with filters

### 3. Bookmarks (Saved Jobs) Test
**Purpose**: Verify save/unsave functionality works without RLS errors.

**Steps**:
1. Navigate to Jobs Screen
2. Find a job listing
3. Click the bookmark/save icon (heart or star)
4. **Expected Result**: Icon changes to indicate saved state
5. Navigate to "Saved Jobs" screen
6. **Expected Result**: Job appears in saved jobs list
7. Click unbookmark/unsave icon
8. **Expected Result**: Job removed from saved jobs

**Verification Query**:
```sql
SELECT * FROM saved_jobs WHERE seeker_id = 'user_id_here';
```

### 4. Resume Upload Test
**Purpose**: Verify resume upload permissions work correctly.

**Steps**:
1. Login as applicant
2. Navigate to profile or job application screen
3. Click "Upload Resume" button
4. Select a PDF file from device
5. **Expected Result**: File uploads successfully
6. Login as employer
7. View an application from the applicant
8. Click "View Resume"
9. **Expected Result**: Resume displays/downloads correctly

**Verification**:
- Check storage.objects table for file entry
- Verify file path follows pattern: `resumes/{user_id}/filename.pdf`

### 5. Company Logo Upload Test
**Purpose**: Verify company logo upload and visibility works.

**Steps**:
1. Login as employer
2. Navigate to company profile settings
3. Click "Upload Logo" button
4. Select an image file
5. **Expected Result**: Logo uploads and displays
6. Login as applicant
7. View job listings from that company
8. **Expected Result**: Company logo displays publicly

### 6. Role-Based Access Test
**Purpose**: Verify proper data isolation between user roles.

#### Applicant Tests:
- ✅ Can view own applications only
- ✅ Can view own saved jobs only
- ✅ Can view own profile only
- ✅ Can view open jobs (all companies)
- ✅ Cannot view other users' applications
- ✅ Cannot access employer dashboard

#### Employer Tests:
- ✅ Can view applications for own jobs only
- ✅ Can view own company profile
- ✅ Can manage own jobs
- ✅ Can view resumes of applicants who applied to their jobs
- ✅ Cannot view other companies' applications
- ✅ Cannot access applicant profiles not related to their jobs

#### Admin Tests:
- ✅ Can view all user data
- ✅ Can view all applications
- ✅ Can view all companies
- ✅ Can view audit logs
- ✅ Can view all storage files
- ✅ Can approve/reject employers

### 7. Chat Functionality Test
**Purpose**: Verify chat permissions work correctly.

**Steps**:
1. Create a job application (applicant → employer)
2. Login as employer
3. Navigate to applications
4. Click "Start Chat" with applicant
5. Send a message
6. **Expected Result**: Message sent successfully
7. Login as applicant
8. Navigate to chats
9. **Expected Result**: Can see and respond to employer's message

### 8. Edge Cases and Security Tests

#### Unauthorized Access Tests:
- ❌ Try to access other users' data (should fail)
- ❌ Try to modify data you don't own (should fail)
- ❌ Try to access admin functions as non-admin (should fail)
- ❌ Try to view other companies' applications (should fail)

#### Session Tests:
- ❌ Test with expired session (should redirect to login)
- ❌ Test with invalid token (should fail gracefully)

#### Data Integrity Tests:
- ✅ Withdraw application that's already withdrawn (should handle gracefully)
- ✅ Save job that's already saved (should not create duplicate)
- ✅ Upload resume when one already exists (should replace)

## Test Results Documentation

### Test Environment
- **Date**: ___________
- **Tester**: ___________
- **Device**: ___________
- **App Version**: ___________

### Test Results Checklist
- [ ] Withdraw button works correctly
- [ ] Filter button works correctly
- [ ] Bookmark/Unbookmark works correctly
- [ ] Resume upload works correctly
- [ ] Logo upload works correctly
- [ ] Role-based permissions correct
- [ ] Chat functionality works
- [ ] Edge cases handled properly
- [ ] No RLS errors in console
- [ ] No unauthorized access possible

### Issues Found
| Issue | Severity | Description | Resolution |
|-------|----------|-------------|------------|
|       |          |             |            |

### Performance Notes
- [ ] Page load times acceptable
- [ ] Filter results load quickly
- [ ] File uploads work smoothly
- [ ] No timeout errors

## Success Criteria
All tests must pass without any RLS permission errors. If any issues are found, report them back to the development team with:
1. Exact steps to reproduce
2. Error messages
3. Expected vs actual behavior
4. Device/browser information

## Rollback Plan
If critical issues are found, use the rollback scripts in `ROLLBACK_SCRIPTS.sql` to revert database changes while maintaining data integrity.
