import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guru_nest/views/dashboard/sections/analytics_section.dart';
import 'package:guru_nest/views/dashboard/sections/category_section.dart';
import 'package:guru_nest/views/dashboard/sections/course_section.dart';
import 'package:guru_nest/views/dashboard/sections/home_section.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  final List<Widget> _sections = [
    const HomeSection(),
    const CourseSection(),
    const CategorySection(),
    const AnalyticsSection(),
  ];

  @override
  void initState() {
    super.initState();
    _updateIndexFromRoute();
  }

  void _updateIndexFromRoute() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final location = GoRouterState.of(context).uri.path;
      int newIndex = 0;

      if (location.contains('/dashboard/courses')) {
        newIndex = 1;
      } else if (location.contains('/dashboard/categories')) {
        newIndex = 2;
      } else if (location.contains('/dashboard/analytics')) {
        newIndex = 3;
      }

      if (newIndex != _currentIndex) {
        setState(() => _currentIndex = newIndex);
      }
    });
  }

  void _onDestinationSelected(int index) {
    if (index == _currentIndex) return;

    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/dashboard/courses');
        break;
      case 2:
        context.go('/dashboard/categories');
        break;
      case 3:
        context.go('/dashboard/analytics');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _sections[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Courses',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}
