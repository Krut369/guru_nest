import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

class ManageMaterialsPage extends StatefulWidget {
  final String courseId;

  const ManageMaterialsPage({
    Key? key,
    required this.courseId,
  }) : super(key: key);

  @override
  State<ManageMaterialsPage> createState() => _ManageMaterialsPageState();
}

class _ManageMaterialsPageState extends State<ManageMaterialsPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _lessons = [];
  String? _selectedLessonId;
  String? _selectedMaterialType;
  final _supabase = supabase.Supabase.instance.client;

  final List<Map<String, dynamic>> _materialTypes = [
    {'id': 'pdf', 'name': 'PDF', 'icon': Icons.picture_as_pdf},
    {'id': 'video', 'name': 'Video', 'icon': Icons.play_circle_fill},
    {'id': 'document', 'name': 'Document', 'icon': Icons.description},
    {'id': 'exercise', 'name': 'Exercise', 'icon': Icons.assignment},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load lessons first
      final lessonsResponse = await _supabase
          .from('lessons')
          .select('id, title')
          .eq('course_id', widget.courseId)
          .order('lesson_order');

      setState(() {
        _lessons = List<Map<String, dynamic>>.from(lessonsResponse);
      });

      // Then load materials
      await _loadMaterials();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMaterials() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('Loading materials with filters:');
      print('Lesson ID: $_selectedLessonId');
      print('Material Type: $_selectedMaterialType');

      var query = _supabase.from('materials').select('''
            *,
            lessons!inner (
              id,
              title,
              courses!inner (
                id,
                title
              )
            )
          ''').eq('lessons.courses.id', widget.courseId);

      // Add lesson filter if a lesson is selected
      if (_selectedLessonId != null && _selectedLessonId!.isNotEmpty) {
        print('Applying lesson filter: $_selectedLessonId');
        query = query.eq('lesson_id', _selectedLessonId!);
      }

      // Add material type filter if a type is selected
      if (_selectedMaterialType != null && _selectedMaterialType!.isNotEmpty) {
        final materialType = _selectedMaterialType!.toLowerCase();
        print('Applying material type filter: $materialType');
        query = query.ilike('type', materialType);
      }

      final response = await query.order('uploaded_at', ascending: false);
      print('Query response length: ${response.length}');

      if (mounted) {
        setState(() {
          _materials = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading materials: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteMaterial(String materialId) async {
    try {
      await _supabase.from('materials').delete().eq('id', materialId);
      await _loadMaterials();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Material deleted successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting material: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _viewMaterial(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open the material'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening material: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedLessonId = null;
      _selectedMaterialType = null;
    });
    _loadMaterials();
  }

  void _showDeleteConfirmation(String materialId, String materialTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Material'),
        content: Text('Are you sure you want to delete "$materialTitle"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMaterial(materialId);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.errorRed),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    // Create temporary variables to hold the filter values
    String? tempLessonId = _selectedLessonId;
    String? tempMaterialType = _selectedMaterialType;

    print('Opening filter dialog with:');
    print('Current Lesson ID: $tempLessonId');
    print('Current Material Type: $tempMaterialType');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Materials'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter by Lesson',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: tempLessonId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  hint: const Text('All Lessons'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Lessons'),
                    ),
                    ..._lessons.map((lesson) {
                      return DropdownMenuItem<String>(
                        value: lesson['id'] as String,
                        child: Text(lesson['title'] as String),
                      );
                    }).toList(),
                  ],
                  onChanged: (String? value) {
                    print('Lesson selected: $value');
                    setDialogState(() {
                      tempLessonId = value;
                    });
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Filter by Material Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._materialTypes.map((type) {
                      final isSelected = tempMaterialType == type['id'];
                      return FilterChip(
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                type['icon'] as IconData,
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  type['name'] as String,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          print('Material type selected: ${type['id']}');
                          setDialogState(() {
                            tempMaterialType =
                                selected ? type['id'] as String : null;
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: AppTheme.primaryBlue,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color:
                              isSelected ? Colors.white : AppTheme.primaryBlue,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.primaryBlue
                                : Colors.grey.shade300,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('Clearing all filters');
                setDialogState(() {
                  tempLessonId = null;
                  tempMaterialType = null;
                });
              },
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () {
                print('Applying filters:');
                print('Lesson ID: $tempLessonId');
                print('Material Type: $tempMaterialType');
                setState(() {
                  _selectedLessonId = tempLessonId;
                  _selectedMaterialType = tempMaterialType;
                });
                Navigator.pop(context);
                _loadMaterials();
              },
              child: const Text('Apply'),
            ),
            TextButton(
              onPressed: () {
                print('Cancelling filter changes');
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMaterialIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'video':
        return Icons.play_circle_fill;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'document':
        return Icons.description;
      case 'exercise':
        return Icons.assignment;
      default:
        return Icons.attach_file;
    }
  }

  Color _getMaterialColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'video':
        return Colors.red.shade100;
      case 'pdf':
        return Colors.blue.shade100;
      case 'document':
        return Colors.green.shade100;
      case 'exercise':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Manage Materials'),
            if (_selectedLessonId != null || _selectedMaterialType != null) ...[
              const SizedBox(width: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (_selectedLessonId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.school,
                            size: 14,
                            color: AppTheme.primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _lessons.firstWhere(
                              (lesson) => lesson['id'] == _selectedLessonId,
                              orElse: () => {'title': 'Unknown Lesson'},
                            )['title'] as String,
                            style: const TextStyle(
                              color: AppTheme.primaryBlue,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedLessonId = null;
                              });
                              _loadMaterials();
                            },
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_selectedMaterialType != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _materialTypes.firstWhere(
                              (type) => type['id'] == _selectedMaterialType,
                              orElse: () => {'icon': Icons.attach_file},
                            )['icon'] as IconData,
                            size: 14,
                            color: AppTheme.primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _materialTypes.firstWhere(
                              (type) => type['id'] == _selectedMaterialType,
                              orElse: () => {'name': 'Unknown'},
                            )['name'] as String,
                            style: const TextStyle(
                              color: AppTheme.primaryBlue,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedMaterialType = null;
                              });
                              _loadMaterials();
                            },
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryBlue,
        actions: [
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
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppTheme.errorRed,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AppTheme.errorRed,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : _materials.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No materials available',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              context.push(
                                  '/teacher/course/${widget.courseId}/add-material');
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Material'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _materials.length,
                      itemBuilder: (context, index) {
                        final material = _materials[index];
                        final lesson =
                            material['lessons'] as Map<String, dynamic>;
                        final course =
                            lesson['courses'] as Map<String, dynamic>;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () => _viewMaterial(material['file_url']),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: _getMaterialColor(
                                                  material['type']),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              _getMaterialIcon(
                                                  material['type']),
                                              color: AppTheme.primaryBlue,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        material['title'] ??
                                                            'Untitled Material',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons.open_in_new,
                                                      size: 16,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Type: ${material['type']?.toUpperCase() ?? 'Unknown'}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 14,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          SizedBox(
                                            width: 40,
                                            child: PopupMenuButton<String>(
                                              padding: EdgeInsets.zero,
                                              icon: const Icon(Icons.more_vert),
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'view',
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.visibility,
                                                          size: 20),
                                                      SizedBox(width: 8),
                                                      Text('View'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.edit,
                                                          size: 20),
                                                      SizedBox(width: 8),
                                                      Text('Edit'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.delete,
                                                          size: 20),
                                                      SizedBox(width: 8),
                                                      Text('Delete'),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                              onSelected: (value) {
                                                if (value == 'view') {
                                                  _viewMaterial(
                                                      material['file_url']);
                                                } else if (value == 'edit') {
                                                  context.push(
                                                    '/teacher/course/${widget.courseId}/edit-material/${material['id']}',
                                                  );
                                                } else if (value == 'delete') {
                                                  _showDeleteConfirmation(
                                                    material['id'],
                                                    material['title'] ??
                                                        'Untitled Material',
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.book,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Course: ${course['title'] ?? 'Untitled Course'}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.school,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Lesson: ${lesson['title'] ?? 'Untitled Lesson'}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: _materials.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                context.push('/teacher/course/${widget.courseId}/add-material');
              },
              backgroundColor: AppTheme.primaryBlue,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
