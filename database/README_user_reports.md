# User Reports System

This document describes the user_reports system that provides efficient analytics tracking for the GuruNest learning platform.

## Overview

The user_reports system consists of:
1. A `user_reports` table that stores pre-calculated analytics data
2. Database triggers that automatically update the table when users perform actions
3. A Flutter service (`UserReportService`) to manage user reports
4. Updated analytics service that uses the pre-calculated data

## Benefits

- **Performance**: Analytics data is pre-calculated and stored, eliminating the need for complex queries
- **Real-time Updates**: Database triggers ensure data is always current
- **Scalability**: Reduces database load for analytics queries
- **Consistency**: Single source of truth for user analytics

## Database Setup

### 1. Create the user_reports table

Run the migration file:
```sql
-- Execute: database/migrations/create_user_reports_table.sql
```

This creates:
- `user_reports` table with all required columns
- Index on `user_id` for fast lookups
- Trigger to update `updated_at` timestamp
- Initial data population for existing users

### 2. Create triggers and functions

Run the functions file:
```sql
-- Execute: database/functions/update_user_reports.sql
```

This creates:
- Functions to update specific metrics
- Triggers that automatically update user_reports when related tables change
- Function to calculate learning streaks
- Function to initialize user reports for existing users

## Table Structure

```sql
CREATE TABLE public.user_reports (
  user_id uuid NOT NULL,
  total_courses_enrolled integer NULL DEFAULT 0,
  total_lessons_accessed integer NULL DEFAULT 0,
  total_materials_accessed integer NULL DEFAULT 0,
  average_quiz_score double precision NULL DEFAULT 0,
  last_quiz_taken timestamp with time zone NULL,
  total_quizzes integer NULL DEFAULT 0,
  learning_streak integer NULL DEFAULT 0,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT user_reports_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);
```

## Automatic Updates

The system automatically updates user_reports when:

1. **Enrollment changes** (`enrollments` table)
   - Updates `total_courses_enrolled`

2. **Lesson access changes** (`lesson_access` table)
   - Updates `total_lessons_accessed`

3. **Material access changes** (`material_access` table)
   - Updates `total_materials_accessed`

4. **Quiz results change** (`quiz_results` table)
   - Updates `total_quizzes`, `average_quiz_score`, `last_quiz_taken`

5. **Learning streak calculation**
   - Calculates consecutive days of activity from all activity tables

## Flutter Integration

### UserReportService

The `UserReportService` provides methods to:

```dart
// Initialize user report for new users
await userReportService.initializeUserReport(userId);

// Update specific metrics
await userReportService.updateOnEnrollment(userId);
await userReportService.updateOnLessonAccess(userId);
await userReportService.updateOnMaterialAccess(userId);
await userReportService.updateOnQuizCompletion(userId, score);
await userReportService.updateLearningStreak(userId);

// Get user report
final report = await userReportService.getUserReport(userId);

// Full update (recalculates all metrics)
await userReportService.updateUserReport(userId);
```

### AnalyticsService Integration

The `AnalyticsService` has been updated to use the user_reports table:

```dart
// The _getUserReport method now fetches from user_reports table
final userReport = await _getUserReport(userId);
```

## Usage Examples

### When a user enrolls in a course

```dart
// After successful enrollment
await userReportService.updateOnEnrollment(userId);
```

### When a user accesses a lesson

```dart
// After recording lesson access
await userReportService.updateOnLessonAccess(userId);
```

### When a user completes a quiz

```dart
// After quiz completion
await userReportService.updateOnQuizCompletion(userId, score);
```

### For new user registration

```dart
// After user creation
await userReportService.initializeUserReport(userId);
```

## Learning Streak Calculation

The learning streak is calculated based on consecutive days of activity from:
- Lesson access (`lesson_access.accessed_at`)
- Material access (`material_access.accessed_at`)
- Quiz completion (`quiz_results.taken_at`)

The streak counts consecutive days from today backwards, breaking when a day is missed.

## Database Triggers

The following triggers ensure automatic updates:

1. `trigger_update_user_reports_on_enrollment`
2. `trigger_update_user_reports_on_lesson_access`
3. `trigger_update_user_reports_on_material_access`
4. `trigger_update_user_reports_on_quiz_result`

## Performance Considerations

- The user_reports table is indexed on `user_id` for fast lookups
- Triggers only update when necessary (INSERT/UPDATE/DELETE)
- Learning streak calculation is optimized to use date-based queries
- The system uses UPSERT operations to handle missing records

## Migration from Old System

If migrating from the old analytics system:

1. Run the migration SQL files
2. The system will automatically populate user_reports for existing users
3. Update your Flutter code to use the new UserReportService
4. The AnalyticsService will automatically use the new table

## Troubleshooting

### Missing user reports
```sql
-- Check if user report exists
SELECT * FROM user_reports WHERE user_id = 'user-uuid-here';

-- Initialize missing user report
SELECT initialize_user_reports();
```

### Incorrect metrics
```sql
-- Recalculate all metrics for a user
SELECT update_learning_streak('user-uuid-here');
```

### Trigger issues
```sql
-- Check if triggers exist
SELECT trigger_name FROM information_schema.triggers 
WHERE event_object_table = 'enrollments';
```

## Monitoring

Monitor the system by checking:

1. **Data consistency**: Compare user_reports with actual table counts
2. **Trigger performance**: Monitor trigger execution times
3. **Storage usage**: Track user_reports table size
4. **Update frequency**: Monitor updated_at timestamps

## Future Enhancements

Potential improvements:
- Add more analytics metrics (time spent, completion rates)
- Implement caching for frequently accessed reports
- Add batch processing for large datasets
- Create admin tools for managing user reports 