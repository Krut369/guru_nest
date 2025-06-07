import 'package:go_router/go_router.dart';

import '../../pages/chat/chat_detail_page.dart';
import '../../pages/teacher/add_material_page.dart';
import '../../pages/teacher/teacher_chat_page.dart';
import '../../screens/teacher/lessons_screen.dart';
import '../../screens/teacher/quiz_management_screen.dart';
import '../../views/dashboard/dashboard_page.dart';
import '../../views/dashboard/sections/my_courses_section.dart';
import '../../views/dashboard/sections/profile_section.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/dashboard',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
      routes: [
        GoRoute(
          path: 'courses',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: 'categories',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: 'analytics',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: 'profile',
          builder: (context, state) => const ProfileSection(),
        ),
        GoRoute(
          path: 'my-courses',
          builder: (context, state) => const MyCoursesSection(),
        ),
      ],
    ),
    GoRoute(
      path: '/teacher',
      builder: (context, state) => const DashboardPage(),
      routes: [
        GoRoute(
          path: 'quizzes',
          builder: (context, state) {
            print('Router: Building quiz management screen');
            return const QuizManagementScreen(
              courseId: '', // This will be handled in the screen
            );
          },
        ),
        GoRoute(
          path: 'courses',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: 'students',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: 'analytics',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: 'chat',
          builder: (context, state) => const TeacherChatPage(),
          routes: [
            GoRoute(
              path: ':conversationId',
              builder: (context, state) {
                final conversationId = state.pathParameters['conversationId']!;
                return ChatDetailPage(conversationId: conversationId);
              },
            ),
          ],
        ),
        GoRoute(
          path: 'lessons',
          builder: (context, state) {
            print('Router: Building lessons screen');
            return const LessonsScreen();
          },
        ),
        // Add course-specific routes
        GoRoute(
          path: 'course/:courseId',
          builder: (context, state) {
            print('Router: Building course page');
            print('Course ID: ${state.pathParameters['courseId']}');
            return const DashboardPage();
          },
          routes: [
            GoRoute(
              path: 'edit-lesson/:lessonId',
              builder: (context, state) => const DashboardPage(),
            ),
            GoRoute(
              path: 'materials',
              builder: (context, state) {
                print('Router: Building materials page');
                print('Course ID: ${state.pathParameters['courseId']}');
                final courseId = state.pathParameters['courseId']!;
                return AddMaterialPage(
                  courseId: courseId,
                  lessonId: '', // This will be handled in the page
                );
              },
            ),
          ],
        ),
      ],
    ),
    // Add a direct route for lessons
    GoRoute(
      path: '/teacher/lessons',
      builder: (context, state) {
        print('Router: Building lessons screen (direct route)');
        return const LessonsScreen();
      },
    ),
  ],
);
