import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';

class CourseSection extends StatefulWidget {
  final String? initialCategory;

  const CourseSection({
    super.key,
    this.initialCategory,
  });

  @override
  State<CourseSection> createState() => _CourseSectionState();
}

class _CourseSectionState extends State<CourseSection> {
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  bool _isLoading = true;
  String? _error;
  final _authService = AuthService();
  User? _currentUser;
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  bool _showPremiumOnly = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    _initializeCourses();
  }

  @override
  void didUpdateWidget(CourseSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != oldWidget.initialCategory) {
      setState(() {
        _selectedCategory = widget.initialCategory ?? 'All';
        _filterCourses();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');

      print('Checking SharedPreferences for user data...');
      print('User JSON from SharedPreferences: $userJson');

      if (userJson != null) {
        final userData = jsonDecode(userJson);
        print('Decoded user data: $userData');

        _currentUser = User.fromJson(userData);
        print(
            'Current user loaded: ${_currentUser?.fullName} (${_currentUser?.email})');

        await _fetchCourses();
      } else {
        print('No user data found in SharedPreferences');
        setState(() {
          _isLoading = false;
          _error = 'Please log in to access courses';
        });
      }
    } catch (e) {
      print('Error initializing courses: $e');
      setState(() {
        _isLoading = false;
        _error = 'Error loading user data: ${e.toString()}';
      });
    }
  }

  Future<void> _fetchCourses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('Fetching courses...');

      // Fetch courses with teacher information only
      final coursesData =
          await Supabase.instance.client.from('courses').select('''
            *,
            users!teacher_id (
              id,
              full_name,
              email
            )
          ''').order('created_at', ascending: false);

      print('Raw courses data: $coursesData');

      // Extract unique categories from the category_id field
      final categories = coursesData
          .map((course) => course['category_id']?.toString() ?? 'Uncategorized')
          .toSet()
          .toList();
      categories.sort();
      categories.insert(0, 'All');

      setState(() {
        _courses = List<Map<String, dynamic>>.from(coursesData);
        _filteredCourses = List.from(_courses);
        _categories = categories;
        _isLoading = false;
      });

      print('Fetched ${_courses.length} courses');
    } catch (e) {
      print('Error fetching courses: $e');
      setState(() {
        _error = 'Failed to load courses: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _filterCourses() {
    setState(() {
      _filteredCourses = _courses.where((course) {
        final title = course['title']?.toString().toLowerCase() ?? '';
        final description =
            course['description']?.toString().toLowerCase() ?? '';
        final searchQuery = _searchController.text.toLowerCase();
        final categoryId = course['category_id']?.toString() ?? 'Uncategorized';
        final isPremium = course['is_premium'] as bool? ?? false;

        final matchesSearch = searchQuery.isEmpty ||
            title.contains(searchQuery) ||
            description.contains(searchQuery);

        final matchesCategory =
            _selectedCategory == 'All' || categoryId == _selectedCategory;
        final matchesPremium = !_showPremiumOnly || isPremium;

        return matchesSearch && matchesCategory && matchesPremium;
      }).toList();
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Filter Courses'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Premium Only Switch
              SwitchListTile(
                title: const Text('Premium Courses Only'),
                value: _showPremiumOnly,
                onChanged: (value) {
                  setState(() {
                    _showPremiumOnly = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _filterCourses();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: CourseSearchDelegate(
                  courses: _courses,
                  onSearch: (results) {
                    setState(() {
                      _filteredCourses = results;
                    });
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.errorRed),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.clear();
                          if (context.mounted) {
                            context.go('/login');
                          }
                        },
                        child: const Text('Go to Login'),
                      ),
                    ],
                  ),
                )
              : _filteredCourses.isEmpty
                  ? const Center(child: Text('No courses available.'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(AppTheme.defaultPadding),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: AppTheme.defaultSpacing,
                        mainAxisSpacing: AppTheme.defaultSpacing,
                      ),
                      itemCount: _filteredCourses.length,
                      itemBuilder: (context, index) {
                        final course = _filteredCourses[index];
                        return _buildCourseCard(context, course);
                      },
                    ),
      floatingActionButton: _currentUser?.role == 'teacher'
          ? FloatingActionButton(
              onPressed: () {
                context.go('/create-course');
              },
              backgroundColor: AppTheme.primaryBlue,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildCourseCard(BuildContext context, Map<String, dynamic> course) {
    final String title = course['title'] ?? 'Untitled Course';
    final String description =
        course['description'] ?? 'No description available';
    final String imageUrl = course['image_url'] ?? '';
    final bool isPremium = course['is_premium'] ?? false;
    final double price = (course['price'] ?? 0.0).toDouble();
    final double rating = (course['rating'] ?? 0.0).toDouble();
    final int enrollments = course['enrollments'] ?? 0;
    final String categoryId =
        course['category_id']?.toString() ?? 'Uncategorized';
    final String teacherName =
        course['users']?['full_name'] ?? 'Unknown Teacher';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final courseId = course['id'];
          if (courseId != null) {
            context.push('/course/$courseId');
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course Image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          child: const Icon(
                            Icons.school,
                            size: 48,
                            color: AppTheme.primaryBlue,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      child: const Icon(
                        Icons.school,
                        size: 48,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
            ),
            // Course Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium Badge
                    if (isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Teacher
                    Text(
                      teacherName,
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Category
                    Text(
                      'Category: $categoryId',
                      style: const TextStyle(
                        color: AppTheme.primaryBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    // Bottom Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Rating
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // Price
                        Text(
                          isPremium ? '\$${price.toStringAsFixed(2)}' : 'Free',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                isPremium ? AppTheme.primaryBlue : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CourseSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> courses;
  final Function(List<Map<String, dynamic>>) onSearch;

  CourseSearchDelegate({
    required this.courses,
    required this.onSearch,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          onSearch(courses);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = courses.where((course) {
      final title = course['title']?.toString().toLowerCase() ?? '';
      final description = course['description']?.toString().toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();

      return title.contains(searchQuery) || description.contains(searchQuery);
    }).toList();

    onSearch(results);

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final course = results[index];
        return ListTile(
          title: Text(course['title'] ?? 'Untitled Course'),
          subtitle: Text(course['description'] ?? 'No description available'),
          onTap: () {
            final courseId = course['id'];
            if (courseId != null) {
              context.push('/course/$courseId');
            }
          },
        );
      },
    );
  }
}
