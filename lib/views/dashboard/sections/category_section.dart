import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';

class CategorySection extends StatefulWidget {
  final Function(String)? onCategorySelected;

  const CategorySection({
    super.key,
    this.onCategorySelected,
  });

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categoriesData = await Supabase.instance.client
          .from('courses')
          .select('category_id')
          .order('category_id');

      // Count courses per category
      final categoryCounts = <String, int>{};
      for (var course in categoriesData) {
        final category = course['category_id']?.toString() ?? 'Uncategorized';
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      setState(() {
        _categories = categoryCounts.entries.map((entry) {
          return {
            'name': entry.key,
            'count': entry.value,
            'icon': _getCategoryIcon(entry.key),
            'color': _getCategoryColor(entry.key),
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load categories: ${e.toString()}';
        _isLoading = false;
      });
    }
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
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
              onPressed: _fetchCategories,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppTheme.defaultPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: AppTheme.defaultSpacing,
        mainAxisSpacing: AppTheme.defaultSpacing,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return Card(
          child: InkWell(
            onTap: () {
              if (widget.onCategorySelected != null) {
                widget.onCategorySelected!(category['name'] as String);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.defaultPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (category['color'] as Color).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      category['icon'] as IconData,
                      color: category['color'] as Color,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: AppTheme.smallSpacing),
                  Text(
                    category['name'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${category['count']} Courses',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
