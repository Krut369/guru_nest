import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lesson_model.dart';
import '../pages/chat/chat_detail_page.dart';
import '../pages/chat/chat_list_page.dart';
import '../pages/chat/new_chat_page.dart';
import '../pages/teacher/manage_enrollments_page.dart';
import '../pages/teacher/manage_lessons_page.dart';
import '../pages/teacher/manage_students_page.dart';
import '../screens/teacher/add_category_screen.dart';
import '../screens/teacher/add_course_screen.dart';
import '../screens/teacher/add_lesson_screen.dart';
import '../screens/teacher/add_material_screen.dart';
import '../screens/teacher/category_management_screen.dart';
import '../screens/teacher/course_management_screen.dart';
import '../screens/teacher/manage_materials_page.dart';
import '../screens/teacher/teacher_dashboard.dart';
import '../views/auth/login_page.dart';
import '../views/auth/register_page.dart';
import '../views/chat/chat_page.dart';
import '../views/course/course_detail_page.dart';
import '../views/dashboard/dashboard_page.dart';
import '../views/dashboard/sections/analytics_section.dart';
import '../views/dashboard/sections/category_section.dart';
import '../views/dashboard/sections/course_section.dart';
import '../views/lesson/lesson_detail_page.dart';
import '../views/quiz/quiz_page.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');

      debugPrint('Current path: ${state.uri.path}');
      debugPrint('User JSON: $userJson');

      // If no user is logged in and not on auth pages, redirect to login
      if (userJson == null &&
          !state.uri.path.startsWith('/login') &&
          !state.uri.path.startsWith('/register')) {
        debugPrint('Redirecting to login - no user found');
        return '/login';
      }

      // If user is logged in and on auth pages, redirect to appropriate dashboard
      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        final role = userData['role'] as String;
        debugPrint('User role: $role');

        if (state.uri.path == '/') {
          final redirectPath =
              role == 'teacher' ? '/teacher/dashboard' : '/dashboard';
          debugPrint('Redirecting to: $redirectPath');
          return redirectPath;
        }

        if (state.uri.path.startsWith('/login') ||
            state.uri.path.startsWith('/register')) {
          final redirectPath =
              role == 'teacher' ? '/teacher/dashboard' : '/dashboard';
          debugPrint('Redirecting to: $redirectPath');
          return redirectPath;
        }
      }

      debugPrint('No redirect needed');
      return null;
    } catch (e, stackTrace) {
      debugPrint('Error in router redirect: $e');
      debugPrint('Stack trace: $stackTrace');
      return '/login';
    }
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
      routes: [
        GoRoute(
          path: 'courses',
          builder: (context, state) {
            final category = state.uri.queryParameters['category'];
            return CourseSection(initialCategory: category);
          },
        ),
        GoRoute(
          path: 'categories',
          builder: (context, state) => const CategorySection(),
        ),
        GoRoute(
          path: 'analytics',
          builder: (context, state) => const AnalyticsSection(),
        ),
      ],
    ),
    GoRoute(
      path: '/teacher',
      builder: (context, state) => const TeacherDashboard(),
      routes: [
        GoRoute(
          path: 'dashboard',
          builder: (context, state) => const TeacherDashboard(),
        ),
        GoRoute(
          path: 'courses',
          builder: (context, state) => const CourseManagementScreen(),
        ),
        GoRoute(
          path: 'students',
          builder: (context, state) => const ManageStudentsPage(),
        ),
        GoRoute(
          path: 'chat',
          builder: (context, state) => const ChatListPage(),
        ),
        GoRoute(
          path: 'chat/new',
          builder: (context, state) => const NewChatPage(),
        ),
        GoRoute(
          path: 'chat/:id',
          builder: (context, state) => ChatDetailPage(
            conversationId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: 'analytics',
          builder: (context, state) => const AnalyticsSection(),
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const TeacherDashboard(),
        ),
        GoRoute(
          path: 'help',
          builder: (context, state) => const TeacherDashboard(),
        ),
        GoRoute(
          path: 'create-course',
          builder: (context, state) => const AddCourseScreen(),
        ),
        GoRoute(
          path: 'add-category',
          builder: (context, state) => const AddCategoryScreen(),
        ),
        GoRoute(
          path: 'categories',
          builder: (context, state) => const CategoryManagementScreen(),
        ),
        GoRoute(
          path: 'course/:courseId/lessons',
          builder: (context, state) => ManageLessonsPage(
            courseId: state.pathParameters['courseId']!,
          ),
        ),
        GoRoute(
          path: 'course/:courseId/materials',
          builder: (context, state) => ManageMaterialsPage(
            courseId: state.pathParameters['courseId']!,
          ),
        ),
        GoRoute(
          path: 'course/:courseId/enrollments',
          builder: (context, state) => ManageEnrollmentsPage(
            courseId: state.pathParameters['courseId']!,
          ),
        ),
        GoRoute(
          path: 'course/:courseId/add-lesson',
          builder: (context, state) => AddLessonScreen(
            courseId: state.pathParameters['courseId']!,
          ),
        ),
        GoRoute(
          path: 'course/:courseId/edit-lesson/:lessonId',
          builder: (context, state) => AddLessonScreen(
            courseId: state.pathParameters['courseId']!,
            lesson: Lesson(
              id: state.pathParameters['lessonId']!,
              courseId: state.pathParameters['courseId']!,
              title: '', // This will be loaded in the screen
              content: '',
              lessonOrder: 1,
            ),
          ),
        ),
        GoRoute(
          path: 'course/:courseId/add-material',
          builder: (context, state) => AddMaterialScreen(
            courseId: state.pathParameters['courseId']!,
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/student/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/chat/:conversationId',
      builder: (context, state) {
        final conversationId = state.pathParameters['conversationId']!;
        if (conversationId == 'new') {
          return const ChatListPage();
        }
        return ChatPage(
          conversationId: conversationId,
        );
      },
    ),
    GoRoute(
      path: '/course/:courseId',
      builder: (context, state) => CourseDetailPage(
        courseId: state.pathParameters['courseId']!,
      ),
    ),
    GoRoute(
      path: '/course/:courseId/lesson/:lessonId',
      builder: (context, state) => LessonDetailPage(
        courseId: state.pathParameters['courseId']!,
        lessonId: state.pathParameters['lessonId']!,
      ),
    ),
    GoRoute(
      path: '/quiz/:quizId',
      builder: (context, state) => QuizPage(
        quizId: state.pathParameters['quizId']!,
      ),
    ),
  ],
);
