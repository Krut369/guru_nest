# Analytics Database Fix Guide

This guide will help you fix the database issues causing the analytics errors in your Flutter app.

## Issues Identified

1. **Missing Tables**: `lesson_access`, `material_access`, `materials`, `quizzes`, `quiz_results`, `messages` tables don't exist
2. **Type Casting Error**: Quiz score data type mismatch (int vs double)
3. **Learning Streak Calculation**: Failing due to missing tables

## Step-by-Step Fix

### 1. Run the Database Setup Script

Execute the `fix_analytics_tables.sql` script in your Supabase SQL editor:

```sql
-- Copy and paste the contents of database/fix_analytics_tables.sql
-- into your Supabase SQL editor and run it
```

This script will:
- Create all missing tables with proper structure
- Set up foreign key relationships
- Create indexes for performance
- Enable Row Level Security (RLS)
- Set up proper RLS policies
- Grant necessary permissions

### 2. Verify the Setup

Run the `test_analytics_setup.sql` script to verify everything is working:

```sql
-- Copy and paste the contents of database/test_analytics_setup.sql
-- into your Supabase SQL editor and run it
```

You should see:
- ✅ EXISTS for all required tables
- Proper table structures
- RLS policies in place
- Indexes created
- Sample data inserted (if tables were empty)

### 3. Test the Flutter App

After running the database scripts:

1. **Restart your Flutter app** to ensure it picks up the new database structure
2. **Navigate to the analytics section** to test if the errors are resolved
3. **Check the console logs** for any remaining errors

## Expected Results

After fixing the database:

- ✅ No more "relation does not exist" errors
- ✅ Quiz statistics should calculate correctly
- ✅ Learning streak should calculate (even if 0 due to no activity)
- ✅ Analytics should show real data from the database

## Troubleshooting

### If you still see errors:

1. **Check Supabase Console**: Verify tables were created in the Table Editor
2. **Check RLS Policies**: Ensure policies are active in the Authentication > Policies section
3. **Check Permissions**: Verify authenticated users have proper permissions
4. **Restart Flutter**: Sometimes the app needs a restart to pick up database changes

### Common Issues:

1. **Foreign Key Errors**: Make sure `lessons`, `courses`, and `users` tables exist
2. **Permission Denied**: Check RLS policies are correctly configured
3. **Connection Issues**: Verify Supabase connection in your Flutter app

## Code Changes Made

The following Flutter code has been updated to handle the issues:

1. **Analytics Service** (`lib/services/analytics_service.dart`):
   - Fixed type casting for quiz scores (handles both int and double)
   - Added error handling for missing tables in learning streak calculation
   - Improved error logging for debugging

2. **Database Structure**:
   - Created all missing tables with proper relationships
   - Added indexes for performance
   - Set up RLS policies for security

## Next Steps

After fixing the database:

1. **Add Sample Data**: Consider adding some sample data to test the analytics
2. **Test Features**: Test lesson completion, quiz taking, and material access
3. **Monitor Performance**: Check if analytics queries are performing well
4. **Add More Metrics**: Consider adding more analytics features as needed

## Files Created/Modified

- `database/fix_analytics_tables.sql` - Main database setup script
- `database/test_analytics_setup.sql` - Verification script
- `lib/services/analytics_service.dart` - Updated with error handling
- `database/ANALYTICS_FIX_README.md` - This guide

## Support

If you encounter any issues after following this guide:

1. Check the Supabase logs for detailed error messages
2. Verify all SQL scripts executed successfully
3. Test with a simple query in the Supabase SQL editor
4. Check Flutter console logs for specific error details 