import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/theme/app_theme.dart';
import '../../../services/auth_service.dart';

class CourseSection extends StatefulWidget {
  final String? initialCategory;
  const CourseSection({super.key, this.initialCategory});

  @override
  State<CourseSection> createState() => _CourseSectionState();
}

class _CourseSectionState extends State<CourseSection> {
  final _authService = AuthService();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _courses = [];
  List<String> _categories = [];
  String? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _initializeCourseData();
  }

  Future<void> _initializeCourseData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _authService.loadSavedUser();
      final userId = _authService.currentUser?.id;

      if (userId == null) {
        setState(() {
          _isLoading = false;
          _error = 'Please log in to access courses';
        });
        return;
      }

      await _fetchCourses();
    } catch (e) {
      print('Error initializing course data: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to initialize data: ${e.toString()}';
      });
    }
  }

  Future<void> _fetchCourses() async {
    final userId = _authService.currentUser?.id;

    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Please log in to access courses';
      });
      return;
    }

    try {
      String query = '''
        *,
        category:categories!category_id (
          name
        ),
        teacher:users!teacher_id (
          id,
          full_name,
          email,
          avatar_url,
          role,
          created_at
        ),
        enrollments!course_id (count),
        rating
      ''';

      var coursesQuery = Supabase.instance.client
          .from('courses')
          .select(query)
          .order('created_at', ascending: false);

      if (_selectedCategory != null) {
        // Filter by category name instead of category_id
        final coursesData = await coursesQuery;
        final filteredCourses = coursesData.where((course) {
          final categoryName =
              course['category']?['name']?.toString() ?? 'Uncategorized';
          return categoryName == _selectedCategory;
        }).toList();

        final categories = coursesData
            .map((course) =>
                course['category']?['name']?.toString() ?? 'Uncategorized')
            .toSet()
            .toList();
        categories.sort();

        setState(() {
          _courses = List<Map<String, dynamic>>.from(filteredCourses);
          _categories = categories;
          _isLoading = false;
        });
        return;
      }

      final coursesData = await coursesQuery;

      final categories = coursesData
          .map((course) =>
              course['category']?['name']?.toString() ?? 'Uncategorized')
          .toSet()
          .toList();
      categories.sort();

      setState(() {
        _courses = List<Map<String, dynamic>>.from(coursesData);
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching courses: $e');
      setState(() {
        _error = 'Failed to load courses: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredCourses {
    if (_searchQuery.isEmpty) {
      return _courses;
    }
    return _courses.where((course) {
      final title = course['title']?.toString().toLowerCase() ?? '';
      final teacher =
          course['teacher']?['full_name']?.toString().toLowerCase() ?? '';
      final category =
          course['category']?['name']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return title.contains(query) ||
          teacher.contains(query) ||
          category.contains(query);
    }).toList();
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'development':
        return Icons.code;
      case 'design':
        return Icons.palette;
      case 'business':
        return Icons.business;
      case 'marketing':
        return Icons.trending_up;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'development':
        return AppTheme.primaryBlue;
      case 'design':
        return AppTheme.warningOrange;
      case 'business':
        return AppTheme.successGreen;
      case 'marketing':
        return AppTheme.errorRed;
      default:
        return AppTheme.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue.withOpacity(0.1),
                      AppTheme.primaryBlue.withOpacity(0.05)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Loading courses...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.red.shade50,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildModernButton(
                  onPressed: _fetchCourses,
                  text: 'Retry',
                  icon: Icons.refresh_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // Modern App Bar
            SliverAppBar(
              backgroundColor: Colors.white,
              elevation: 2,
              pinned: true,
              expandedHeight: 140,
              leading: Navigator.of(context).canPop()
                  ? IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(bottom: 16),
                centerTitle: true,
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Explore Courses',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 18 : 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Discover amazing courses from expert instructors',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            // Search and Filter Section
            SliverToBoxAdapter(child: _buildSearchAndFilterSection(isTablet)),
            // Category Filter Chips
            SliverToBoxAdapter(child: _buildCategoryChips()),
            // Courses Grid
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 24),
              sliver: _buildCoursesGrid(isTablet),
            ),
            // Bottom spacing
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterSection(bool isTablet) {
    return Container(
      margin:
          EdgeInsets.symmetric(horizontal: isTablet ? 32 : 24, vertical: 16),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search courses, instructors, or categories...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 16,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.grey,
                            size: 16,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Filter Row
          Row(
            children: [
              // Active Filters Display
              if (_selectedCategory != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        _getCategoryColor(_selectedCategory!).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getCategoryColor(_selectedCategory!)
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getCategoryIcon(_selectedCategory!),
                        size: 16,
                        color: _getCategoryColor(_selectedCategory!),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedCategory!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _getCategoryColor(_selectedCategory!),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = null;
                          });
                          _fetchCourses();
                        },
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: _getCategoryColor(_selectedCategory!),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
              // Filter Button
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue,
                      AppTheme.primaryBlue.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showCategoryFilter(context),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Filter',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _categories.length + 1, // +1 for "All" option
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return ActionChip(
              label: const Text('All',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              avatar:
                  const Icon(Icons.all_inclusive, color: AppTheme.primaryBlue),
              backgroundColor: _selectedCategory == null
                  ? AppTheme.primaryBlue.withOpacity(0.2)
                  : AppTheme.primaryBlue.withOpacity(0.1),
              onPressed: () {
                setState(() {
                  _selectedCategory = null;
                });
                _fetchCourses();
              },
            );
          }

          final category = _categories[index - 1];
          return ActionChip(
            label: Text(category,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            avatar: Icon(_getCategoryIcon(category),
                color: _getCategoryColor(category)),
            backgroundColor: _selectedCategory == category
                ? _getCategoryColor(category).withOpacity(0.2)
                : _getCategoryColor(category).withOpacity(0.1),
            onPressed: () {
              setState(() {
                _selectedCategory = category;
              });
              _fetchCourses();
            },
          );
        },
      ),
    );
  }

  Widget _buildCoursesGrid(bool isTablet) {
    if (_filteredCourses.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          height: 300,
          margin: const EdgeInsets.only(top: 50),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No courses found for "$_searchQuery"'
                      : 'No courses available',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    child: const Text('Clear search'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 3 : 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final course = _filteredCourses[index];
          return _buildCourseCard(course, isTablet);
        },
        childCount: _filteredCourses.length,
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, bool isTablet) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () async {
          final courseId = course['id'];
          if (courseId != null) {
            await context.push('/course/$courseId');
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue.withOpacity(0.8),
                      AppTheme.primaryBlue.withOpacity(0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: course['image_url'] != null
                    ? Image.network(
                        course['image_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderImage();
                        },
                      )
                    : _buildPlaceholderImage(),
              ),
            ),
            // Course Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(course['category']
                                      ?['name'] ??
                                  'Uncategorized')
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getCategoryIcon(course['category']?['name'] ??
                                  'Uncategorized'),
                              size: 12,
                              color: _getCategoryColor(course['category']
                                      ?['name'] ??
                                  'Uncategorized'),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              course['category']?['name'] ?? 'Uncategorized',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _getCategoryColor(course['category']
                                        ?['name'] ??
                                    'Uncategorized'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Course Title
                      Text(
                        course['title'] ?? 'Untitled Course',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.textDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Teacher Info
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor:
                                AppTheme.primaryBlue.withOpacity(0.1),
                            backgroundImage: course['teacher']?['avatar_url'] !=
                                    null
                                ? NetworkImage(course['teacher']['avatar_url'])
                                : null,
                            child: course['teacher']?['avatar_url'] == null
                                ? Text(
                                    (course['teacher']?['full_name'] ??
                                            'Unknown Teacher')
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              course['teacher']?['full_name'] ??
                                  'Unknown Teacher',
                              style: const TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Course Stats
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (course['rating'] ?? 0.0).toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.group,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${course['enrollments']?[0]?['count'] ?? 0}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withOpacity(0.8),
            AppTheme.primaryBlue.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.book_rounded,
        color: Colors.white,
        size: 48,
      ),
    );
  }

  void _showCategoryFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter by Category',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedCategory == null,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = null;
                          });
                          _fetchCourses();
                          Navigator.pop(context);
                        },
                        selectedColor: AppTheme.primaryBlue.withOpacity(0.2),
                        checkmarkColor: AppTheme.primaryBlue,
                      ),
                      ..._categories.map((category) => FilterChip(
                            label: Text(category),
                            selected: _selectedCategory == category,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = selected ? category : null;
                              });
                              _fetchCourses();
                              Navigator.pop(context);
                            },
                            selectedColor:
                                _getCategoryColor(category).withOpacity(0.2),
                            checkmarkColor: _getCategoryColor(category),
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required VoidCallback onPressed,
    required String text,
    required IconData icon,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: Icon(icon, size: 20),
      label: Text(text),
    );
  }
}
