# Analytics System Documentation

## Overview

The analytics system in Guru Nest uses a `user_reports` table to track user learning progress and provide comprehensive analytics for both students and teachers.

## Database Schema

### user_reports Table

```sql
CREATE TABLE public.user_reports (
  user_id uuid NOT NULL,
  total_courses_enrolled integer NULL DEFAULT 0,
  total_lessons_accessed integer NULL DEFAULT 0,
  total_materials_accessed integer NULL DEFAULT 0,
  average_quiz_score double precision NULL DEFAULT 0,
  last_quiz_taken timestamp with time zone NULL,
  total_quizzes integer NULL DEFAULT 0,
  CONSTRAINT user_reports_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);
```

### Key Features

- **Automatic Updates**: The system automatically updates user reports when users interact with courses, lessons, materials, and quizzes
- **Real-time Analytics**: Analytics are calculated in real-time from the database
- **Comprehensive Metrics**: Tracks multiple learning metrics for detailed insights

## Services

### 1. UserReportsService (`lib/services/user_reports_service.dart`)

Handles basic CRUD operations for user reports:

```dart
// Get user report
final report = await userReportsService.getUserReport(userId);

// Update specific metrics
await userReportsService.updateUserReport(
  userId: userId,
  totalCoursesEnrolled: 5,
  averageQuizScore: 85.5,
);

// Increment counters
await userReportsService.incrementCoursesEnrolled(userId);
await userReportsService.incrementLessonsAccessed(userId);
await userReportsService.incrementMaterialsAccessed(userId);

// Update quiz scores
await userReportsService.updateQuizScore(userId, 90.0);
```

### 2. AnalyticsService (`lib/services/analytics_service.dart`)

Provides comprehensive analytics for different user types:

```dart
// Student analytics
final studentAnalytics = await analyticsService.getStudentAnalytics(userId);

// Teacher analytics
final teacherAnalytics = await analyticsService.getTeacherAnalytics(teacherId);

// Platform analytics (for admins)
final platformAnalytics = await analyticsService.getPlatformAnalytics();
```

## Integration Points

### Course Enrollment
When a student enrolls in a course, the system automatically:
1. Creates/updates enrollment record
2. Increments `total_courses_enrolled` in user_reports

**Location**: `lib/services/course_service.dart` - `enrollInCourse()` method

### Lesson Access
When a student accesses a lesson, the system automatically:
1. Records lesson access
2. Increments `total_lessons_accessed` in user_reports

**Location**: `lib/services/course_service.dart` - `markLessonAsAccessed()` method

### Material Access
When a student downloads/accesses material, the system automatically:
1. Records material access
2. Increments `total_materials_accessed` in user_reports

**Location**: `lib/services/course_service.dart` - `markMaterialAsAccessed()` method

### Quiz Completion
When a student completes a quiz, the system automatically:
1. Records quiz result
2. Updates `average_quiz_score`, `last_quiz_taken`, and `total_quizzes` in user_reports

**Location**: `lib/services/user_reports_service.dart` - `updateQuizScore()` method

## Analytics Screens

### Student Analytics (`lib/views/dashboard/sections/analytics_section.dart`)

Displays:
- Courses enrolled
- Lessons completed
- Materials accessed
- Average quiz score
- Total quizzes taken
- Last quiz date
- Learning progress charts
- Recent activity feed

### Teacher Analytics

Displays:
- Total courses created
- Total students enrolled
- Total revenue generated
- Course performance metrics
- Student engagement rates
- Recent activities
- Category distribution

## Database Functions

The system includes PostgreSQL functions for efficient counter updates:

```sql
-- Increment courses enrolled
CREATE OR REPLACE FUNCTION increment_courses_enrolled(user_id uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO public.user_reports (user_id, total_courses_enrolled)
  VALUES (user_id, 1)
  ON CONFLICT (user_id)
  DO UPDATE SET total_courses_enrolled = user_reports.total_courses_enrolled + 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

Similar functions exist for:
- `increment_lessons_accessed(user_id uuid)`
- `increment_materials_accessed(user_id uuid)`

## Security

### Row Level Security (RLS)
The `user_reports` table has RLS enabled with policies:
- Users can only view their own reports
- Users can only update their own reports
- Users can only insert their own reports

### Data Privacy
- All analytics are user-specific
- No cross-user data sharing
- Secure API endpoints with authentication

## Usage Examples

### Getting Student Progress
```dart
final analyticsService = AnalyticsService();
final analytics = await analyticsService.getStudentAnalytics(userId);

print('Courses enrolled: ${analytics['user_report']['total_courses_enrolled']}');
print('Average quiz score: ${analytics['user_report']['average_quiz_score']}%');
print('Total lessons accessed: ${analytics['user_report']['total_lessons_accessed']}');
```

### Getting Teacher Dashboard Data
```dart
final analyticsService = AnalyticsService();
final analytics = await analyticsService.getTeacherAnalytics(teacherId);

print('Total courses: ${analytics['total_courses']}');
print('Total students: ${analytics['total_students']}');
print('Total revenue: \$${analytics['total_revenue']}');
```

### Manual Report Updates
```dart
final userReportsService = UserReportsService();

// Update specific metrics
await userReportsService.updateUserReport(
  userId: userId,
  totalCoursesEnrolled: 10,
  totalLessonsAccessed: 50,
  totalMaterialsAccessed: 25,
  averageQuizScore: 88.5,
  totalQuizzes: 15,
);
```

## Performance Considerations

1. **Indexes**: The table includes indexes on `user_id` and `last_quiz_taken` for optimal query performance
2. **Caching**: Consider implementing caching for frequently accessed analytics data
3. **Batch Updates**: For bulk operations, consider batch updates to reduce database calls
4. **Pagination**: Large datasets should be paginated to avoid memory issues

## Future Enhancements

1. **Advanced Analytics**: Add machine learning insights and predictions
2. **Export Features**: Allow users to export their analytics data
3. **Comparative Analytics**: Compare performance across time periods
4. **Gamification**: Add badges and achievements based on analytics
5. **Real-time Notifications**: Alert users about their progress milestones

## Troubleshooting

### Common Issues

1. **Missing User Reports**: If a user report doesn't exist, the system automatically creates one with default values
2. **Duplicate Entries**: The system uses upsert operations to prevent duplicates
3. **Performance Issues**: Ensure proper indexing and consider query optimization for large datasets

### Debugging

Enable debug logging in the services to track analytics operations:
```dart
print('Error updating user report: $e');
print('Analytics data loaded: ${analytics.length} records');
```

## Database Migration

To set up the analytics system in a new environment:

1. Run the SQL script from `database/user_reports_table.sql`
2. Ensure RLS policies are properly configured
3. Test the increment functions with sample data
4. Verify analytics service integration

## API Endpoints

The analytics system is primarily used through the Flutter services, but could be exposed via REST API endpoints for web integration:

- `GET /api/analytics/student/{userId}` - Get student analytics
- `GET /api/analytics/teacher/{teacherId}` - Get teacher analytics
- `GET /api/analytics/platform` - Get platform-wide analytics
- `PUT /api/analytics/user-reports/{userId}` - Update user report 