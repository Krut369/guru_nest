import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guru_nest/core/theme/app_theme.dart';
import 'package:guru_nest/models/user_model.dart';
import 'package:guru_nest/pages/notifications/notifications_page.dart';
import 'package:guru_nest/pages/profile/profile_page.dart';
import 'package:guru_nest/services/notifications_service.dart';
import 'package:guru_nest/views/dashboard/sections/analytics_section.dart';
import 'package:guru_nest/views/dashboard/sections/category_section.dart';
import 'package:guru_nest/views/dashboard/sections/chat_section.dart';
import 'package:guru_nest/views/dashboard/sections/course_section.dart';
import 'package:guru_nest/views/dashboard/sections/home_section.dart';
import 'package:guru_nest/views/dashboard/sections/my_courses_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  final String? selectedCategory;
  const DashboardPage({super.key, this.selectedCategory});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;
  String? _selectedCategory;
  User? _currentUser;
  final NotificationsService _notificationsService = NotificationsService();
  int _unreadNotificationCount = 0;

  final List<Widget> _sections = [];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _loadUserData();
    _initializeSections();
    _loadUnreadNotificationCount();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');

      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        setState(() {
          _currentUser = User.fromJson(userData);
        });
        // Load notification count after user data is loaded
        _loadUnreadNotificationCount();
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadUnreadNotificationCount() async {
    if (_currentUser?.id == null) return;

    try {
      final count = await _notificationsService
          .getUnreadNotificationCount(_currentUser!.id);
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    } catch (e) {
      print('Error loading unread notification count: $e');
    }
  }

  void _initializeSections() {
    _sections.clear();
    _sections.addAll([
      const HomeSection(),
      MyCoursesSection(onBrowseCourses: _onBrowseCourses),
      CourseSection(initialCategory: _selectedCategory),
      CategorySection(onCategorySelected: _onCategorySelected),
      const ChatSection(),
      const AnalyticsSection(),
      const ProfilePage(),
    ]);
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _currentIndex = 2; // Switch to Browse section
      _initializeSections(); // Rebuild sections with new category
    });
  }

  void _onBrowseCourses() {
    setState(() {
      _currentIndex = 2; // Switch to Browse section
    });
  }

  void _onDestinationSelected(int index) {
    if (index == _currentIndex) return;

    // Map bottom navigation indices to section indices
    int sectionIndex;
    switch (index) {
      case 0: // Home
        sectionIndex = 0;
        break;
      case 1: // My Courses
        sectionIndex = 1;
        break;
      case 2: // Chat
        sectionIndex = 4;
        break;
      case 3: // Analytics
        sectionIndex = 5;
        break;
      case 4: // Profile
        sectionIndex = 6;
        break;
      default:
        sectionIndex = 0;
    }

    setState(() => _currentIndex = sectionIndex);
  }

  // Map section index to bottom navigation index
  int _getBottomNavIndex() {
    switch (_currentIndex) {
      case 0: // Home
        return 0;
      case 1: // My Courses
        return 1;
      case 4: // Chat
        return 2;
      case 5: // Analytics
        return 3;
      case 6: // Profile
        return 4;
      default:
        return 0;
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getSectionTitle()),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsPage(),
                    ),
                  ).then((_) {
                    // Refresh notification count when returning from notifications page
                    _loadUnreadNotificationCount();
                  });
                },
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotificationCount > 99
                          ? '99+'
                          : _unreadNotificationCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _sections[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getBottomNavIndex(),
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'My Courses',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          // User header
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: AppTheme.primaryBlue,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: _currentUser?.avatarUrl != null
                  ? NetworkImage(_currentUser!.avatarUrl!) as ImageProvider
                  : null,
              child: _currentUser?.avatarUrl == null
                  ? const Icon(
                      Icons.person,
                      color: AppTheme.primaryBlue,
                      size: 40,
                    )
                  : null,
            ),
            accountName: Text(
              _currentUser?.fullName ?? 'Student',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            accountEmail: Text(
              _currentUser?.email ?? 'student@example.com',
              style: const TextStyle(
                color: Colors.white70,
              ),
            ),
          ),

          // Navigation items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.home,
                  title: 'Home',
                  onTap: () {
                    setState(() => _currentIndex = 0);
                    Navigator.pop(context);
                  },
                  isSelected: _currentIndex == 0,
                ),
                _buildDrawerItem(
                  icon: Icons.book,
                  title: 'My Courses',
                  onTap: () {
                    setState(() => _currentIndex = 1);
                    Navigator.pop(context);
                  },
                  isSelected: _currentIndex == 1,
                ),
                _buildDrawerItem(
                  icon: Icons.school,
                  title: 'Browse Courses',
                  onTap: () {
                    setState(() => _currentIndex = 2);
                    Navigator.pop(context);
                  },
                  isSelected: _currentIndex == 2,
                ),
                // _buildDrawerItem(
                //   icon: Icons.category,
                //   title: 'Categories',
                //   onTap: () {
                //     setState(() => _currentIndex = 3);
                //     Navigator.pop(context);
                //   },
                //   isSelected: _currentIndex == 3,
                // ),
                _buildDrawerItem(
                  icon: Icons.chat,
                  title: 'Messages',
                  onTap: () {
                    setState(() => _currentIndex = 4);
                    Navigator.pop(context);
                  },
                  isSelected: _currentIndex == 4,
                ),
                _buildDrawerItem(
                  icon: Icons.analytics,
                  title: 'Analytics',
                  onTap: () {
                    setState(() => _currentIndex = 5);
                    Navigator.pop(context);
                  },
                  isSelected: _currentIndex == 5,
                ),
                // const Divider(),
                _buildDrawerItem(
                  icon: Icons.person,
                  title: 'Profile',
                  onTap: () {
                    setState(() => _currentIndex = 6);
                    Navigator.pop(context);
                  },
                  isSelected: _currentIndex == 6,
                ),
                // _buildDrawerItem(
                //   icon: Icons.settings,
                //   title: 'Settings',
                //   onTap: () {
                //     Navigator.pop(context);
                //     ScaffoldMessenger.of(context).showSnackBar(
                //       const SnackBar(
                //         content: Text('Settings coming soon!'),
                //         duration: Duration(seconds: 2),
                //       ),
                //     );
                //   },
                // ),
                // _buildDrawerItem(
                //   icon: Icons.help,
                //   title: 'Help & Support',
                //   onTap: () {
                //     Navigator.pop(context);
                //     ScaffoldMessenger.of(context).showSnackBar(
                //       const SnackBar(
                //         content: Text('Help & Support coming soon!'),
                //         duration: Duration(seconds: 2),
                //       ),
                //     );
                //   },
                // ),
                // const Divider(),
                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryBlue : Colors.grey[600],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryBlue : Colors.grey[800],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: onTap,
    );
  }

  String _getSectionTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Home';
      case 1:
        return 'My Courses';
      case 2:
        return 'Browse Courses';
      case 3:
        return 'Categories';
      case 4:
        return 'Messages';
      case 5:
        return 'Analytics';
      case 6:
        return 'Profile';
      default:
        return 'Dashboard';
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}
