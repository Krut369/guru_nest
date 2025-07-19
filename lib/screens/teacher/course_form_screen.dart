import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/course_service.dart';

class CourseFormScreen extends StatefulWidget {
  final Map<String, dynamic>? course;

  const CourseFormScreen({
    Key? key,
    this.course,
  }) : super(key: key);

  @override
  State<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends State<CourseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _courseService = CourseService();
  final _supabase = Supabase.instance.client;

  XFile? _imageFile;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _isLoadingCategories = true;

  String? _selectedCategoryId;
  String? _selectedLevel;
  String? _selectedLanguage;
  bool _isPremium = false;

  List<Map<String, dynamic>> _categories = [];
  List<String> _learnings = [];
  List<Map<String, dynamic>> _includes = [];

  final List<String> _levels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'All Levels'
  ];

  final List<String> _languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Japanese'
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.course != null) {
      _loadCourseData();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _loadCourseData() {
    final course = widget.course!;
    _titleController.text = course['title'] ?? '';
    _descriptionController.text = course['description'] ?? '';
    _priceController.text = course['price']?.toString() ?? '';
    _selectedCategoryId = course['category_id']?.toString();
    _selectedLevel = course['level'] ?? 'Beginner';
    _selectedLanguage = course['language'] ?? 'English';
    _isPremium = course['is_premium'] ?? false;

    _loadCourseDetails();
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoadingCategories = true;
      });

      final response =
          await _supabase.from('categories').select('id, name').order('name');

      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
        _isLoadingCategories = false;
      });
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _loadCourseDetails() async {
    if (widget.course == null) return;

    try {
      final courseId = widget.course!['id'];

      final learningsResponse = await _supabase
          .from('course_learnings')
          .select('description')
          .eq('course_id', courseId);

      final includesResponse = await _supabase
          .from('course_includes')
          .select('icon, title')
          .eq('course_id', courseId);

      setState(() {
        _learnings =
            List<String>.from(learningsResponse.map((l) => l['description']));
        _includes = List<Map<String, dynamic>>.from(includesResponse);
      });
    } catch (e) {
      print('Error loading course details: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageFile = pickedFile;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.course == null && _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a course image')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson == null) {
        throw Exception('User not authenticated');
      }

      final userData = jsonDecode(userJson);
      final user = User.fromJson(userData);

      if (widget.course == null) {
        // CREATE MODE
        await _courseService.createCourse(
          title: _titleController.text,
          description: _descriptionController.text,
          price: _isPremium ? double.parse(_priceController.text) : 0.0,
          categoryId: _selectedCategoryId!,
          imageBytes: _imageBytes,
          teacherId: user.id,
        );

        // Get the created course ID for saving learnings and includes
        final courses = await _supabase
            .from('courses')
            .select('id')
            .eq('title', _titleController.text)
            .eq('teacher_id', user.id)
            .order('created_at', ascending: false)
            .limit(1);

        if (courses.isNotEmpty) {
          final courseId = courses.first['id'];
          await _saveCourseDetails(courseId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Course created successfully'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // EDIT MODE
        final String courseId = widget.course!['id'];

        // Update course basic info
        await _courseService.updateCourse(
          courseId: courseId,
          title: _titleController.text,
          description: _descriptionController.text,
          price: _isPremium ? double.parse(_priceController.text) : 0.0,
          categoryId: _selectedCategoryId,
          imageFile: _imageFile != null ? File(_imageFile!.path) : null,
        );

        // Update course details
        await _saveCourseDetails(courseId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Course updated successfully'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.course == null
                ? 'Error creating course: $e'
                : 'Error updating course: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveCourseDetails(String courseId) async {
    // Save learnings
    if (_learnings.isNotEmpty) {
      await _supabase
          .from('course_learnings')
          .delete()
          .eq('course_id', courseId);

      for (final learning in _learnings) {
        await _supabase.from('course_learnings').insert({
          'course_id': courseId,
          'description': learning,
        });
      }
    }

    // Save includes
    if (_includes.isNotEmpty) {
      await _supabase
          .from('course_includes')
          .delete()
          .eq('course_id', courseId);

      for (final include in _includes) {
        await _supabase.from('course_includes').insert({
          'course_id': courseId,
          'icon': include['icon'],
          'title': include['title'],
        });
      }
    }
  }

  void _addLearning() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Learning Outcome'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'What will students learn?',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _learnings.add(controller.text.trim());
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editLearning(int index, String learning) {
    final controller = TextEditingController(text: learning);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Learning Outcome'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'What will students learn?',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _learnings[index] = controller.text.trim();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addInclude() {
    final titleController = TextEditingController();
    String? selectedIcon;

    // Define available icons with their names
    final Map<String, IconData> availableIcons = {
      'video': IconlyBold.video,
      'download': IconlyBold.download,
      'access': IconlyBold.time_circle,
      'certificate': IconlyBold.tick_square,
      'book': IconlyBold.bookmark,
      'file': IconlyBold.document,
      'calendar': IconlyBold.calendar,
      'message': IconlyBold.message,
      'notification': IconlyBold.notification,
      'star': IconlyBold.star,
      'heart': IconlyBold.heart,
      'check': IconlyBold.tick_square,
      'play': IconlyBold.play,
      'volume': IconlyBold.volume_up,
      'camera': IconlyBold.camera,
      'image': IconlyBold.image,
      'folder': IconlyBold.folder,
      'home': IconlyBold.home,
      'settings': IconlyBold.setting,
      'search': IconlyBold.search,
      'plus': IconlyBold.plus,
      'close': IconlyBold.close_square,
      'edit': IconlyBold.edit,
      'delete': IconlyBold.delete,
      'share': IconlyBold.send,
      'lock': IconlyBold.lock,
      'unlock': IconlyBold.unlock,
      'eye': IconlyBold.show,
      'hide': IconlyBold.hide,
      'filter': IconlyBold.filter,
      'grid': IconlyBold.category,
      'more': IconlyBold.more_circle,
      'back': IconlyBold.arrow_left,
      'forward': IconlyBold.arrow_right,
      'up': IconlyBold.arrow_up,
      'down': IconlyBold.arrow_down,
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Course Include'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedIcon,
                decoration: const InputDecoration(
                  labelText: 'Select Icon *',
                  border: OutlineInputBorder(),
                ),
                items: availableIcons.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(entry.value,
                            color: AppTheme.primaryBlue, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            entry.key.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedIcon = value;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an icon';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  hintText: 'Title (e.g., 10 hours on-demand video)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty &&
                  selectedIcon != null) {
                setState(() {
                  _includes.add({
                    'icon': selectedIcon!,
                    'title': titleController.text.trim(),
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.course == null ? 'Create Course' : 'Edit Course',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _submitForm,
              child: Text(
                widget.course == null ? 'Create' : 'Save',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.all(
                    constraints.maxWidth > 600 ? 24.0 : 16.0,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth > 800
                          ? 800
                          : constraints.maxWidth,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Course Image Section
                          _buildSectionCard(
                            'Course Image',
                            Icons.image,
                            Column(
                              children: [
                                Center(
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      width: 200,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppTheme.primaryBlue
                                              .withOpacity(0.3),
                                          width: 2,
                                        ),
                                        image: _imageBytes != null
                                            ? DecorationImage(
                                                image:
                                                    MemoryImage(_imageBytes!),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: _imageBytes == null
                                          ? Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.add_photo_alternate,
                                                  size: 50,
                                                  color: AppTheme.primaryBlue
                                                      .withOpacity(0.6),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Tap to add image',
                                                  style: TextStyle(
                                                    color: AppTheme.primaryBlue
                                                        .withOpacity(0.6),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                if (_imageBytes != null) ...[
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: _pickImage,
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Change Image'),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Basic Information Section
                          _buildSectionCard(
                            'Basic Information',
                            Icons.info,
                            Column(
                              children: [
                                TextFormField(
                                  controller: _titleController,
                                  decoration: const InputDecoration(
                                    labelText: 'Course Title *',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value?.trim().isEmpty ?? true) {
                                      return 'Please enter a course title';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _descriptionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Description',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 4,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Course Details Section
                          _buildSectionCard(
                            'Course Details',
                            Icons.settings,
                            Column(
                              children: [
                                if (_isLoadingCategories)
                                  const Center(
                                      child: CircularProgressIndicator())
                                else
                                  DropdownButtonFormField<String>(
                                    value: _selectedCategoryId,
                                    decoration: const InputDecoration(
                                      labelText: 'Category *',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _categories.map((category) {
                                      return DropdownMenuItem<String>(
                                        value: category['id'].toString(),
                                        child: Text(category['name']),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedCategoryId = value;
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please select a category';
                                      }
                                      return null;
                                    },
                                  ),
                                const SizedBox(height: 16),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth < 400) {
                                      // Stack vertically on very small screens
                                      return Column(
                                        children: [
                                          DropdownButtonFormField<String>(
                                            value: _selectedLevel,
                                            decoration: const InputDecoration(
                                              labelText: 'Level',
                                              border: OutlineInputBorder(),
                                            ),
                                            items: _levels.map((level) {
                                              return DropdownMenuItem(
                                                value: level,
                                                child: Text(level),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedLevel = value;
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          DropdownButtonFormField<String>(
                                            value: _selectedLanguage,
                                            decoration: const InputDecoration(
                                              labelText: 'Language',
                                              border: OutlineInputBorder(),
                                            ),
                                            items: _languages.map((language) {
                                              return DropdownMenuItem(
                                                value: language,
                                                child: Text(language),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedLanguage = value;
                                              });
                                            },
                                          ),
                                        ],
                                      );
                                    } else {
                                      // Use Row on larger screens
                                      return Row(
                                        children: [
                                          Expanded(
                                            child:
                                                DropdownButtonFormField<String>(
                                              value: _selectedLevel,
                                              decoration: const InputDecoration(
                                                labelText: 'Level',
                                                border: OutlineInputBorder(),
                                              ),
                                              items: _levels.map((level) {
                                                return DropdownMenuItem(
                                                  value: level,
                                                  child: Text(level),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedLevel = value;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child:
                                                DropdownButtonFormField<String>(
                                              value: _selectedLanguage,
                                              decoration: const InputDecoration(
                                                labelText: 'Language',
                                                border: OutlineInputBorder(),
                                              ),
                                              items: _languages.map((language) {
                                                return DropdownMenuItem(
                                                  value: language,
                                                  child: Text(language),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedLanguage = value;
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Pricing Section
                          _buildSectionCard(
                            'Pricing',
                            Icons.attach_money,
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _isPremium,
                                      onChanged: (value) {
                                        setState(() {
                                          _isPremium = value ?? false;
                                        });
                                      },
                                    ),
                                    const Text('Premium Course'),
                                  ],
                                ),
                                if (_isPremium) ...[
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _priceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Price (\$) *',
                                      border: OutlineInputBorder(),
                                      prefixText: '\$',
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (_isPremium &&
                                          (value?.trim().isEmpty ?? true)) {
                                        return 'Please enter a price for premium courses';
                                      }
                                      if (value?.isNotEmpty ?? false) {
                                        final price = double.tryParse(value!);
                                        if (price == null || price < 0) {
                                          return 'Please enter a valid price';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Learning Outcomes Section
                          _buildSectionCard(
                            'Learning Outcomes',
                            Icons.school,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_learnings.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.lightbulb_outline,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No learning outcomes added yet',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Add what students will learn from this course',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[500],
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children:
                                        _learnings.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final learning = entry.value;
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.primaryBlue
                                                  .withOpacity(0.1),
                                              AppTheme.primaryBlue
                                                  .withOpacity(0.05),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: AppTheme.primaryBlue
                                                .withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            onTap: () =>
                                                _editLearning(index, learning),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.check_circle,
                                                    size: 18,
                                                    color: AppTheme.primaryBlue,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      learning,
                                                      style: const TextStyle(
                                                        color: AppTheme
                                                            .primaryBlue,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        _learnings
                                                            .removeAt(index);
                                                      });
                                                    },
                                                    child: Icon(
                                                      Icons.close,
                                                      size: 16,
                                                      color: AppTheme
                                                          .primaryBlue
                                                          .withOpacity(0.7),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _addLearning,
                                    icon: const Icon(Icons.add, size: 20),
                                    label: const Text(
                                      'Add Learning Outcome',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Course Includes Section
                          _buildSectionCard(
                            'Course Includes',
                            Icons.checklist,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_includes.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.playlist_add_check,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No course includes added yet',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Add what is included in this course (e.g., videos, resources)',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[500],
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children:
                                        _includes.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final include = entry.value;
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.primaryBlue
                                                  .withOpacity(0.1),
                                              AppTheme.primaryBlue
                                                  .withOpacity(0.05),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: AppTheme.primaryBlue
                                                .withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            onTap: null,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _getIconFromString(
                                                        include['icon']),
                                                    size: 18,
                                                    color: AppTheme.primaryBlue,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      include['title'],
                                                      style: const TextStyle(
                                                        color: AppTheme
                                                            .primaryBlue,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        _includes
                                                            .removeAt(index);
                                                      });
                                                    },
                                                    child: Icon(
                                                      Icons.close,
                                                      size: 16,
                                                      color: AppTheme
                                                          .primaryBlue
                                                          .withOpacity(0.7),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _addInclude,
                                    icon: const Icon(Icons.add, size: 20),
                                    label: const Text(
                                      'Add Course Include',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : Text(
                                      widget.course == null
                                          ? 'Create Course'
                                          : 'Update Course',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, Widget content) {
    return Card(
      elevation: 2,
      shadowColor: AppTheme.primaryBlue.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              AppTheme.primaryBlue.withOpacity(0.02),
              AppTheme.primaryBlue.withOpacity(0.05),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }

  IconData _getIconFromString(String? iconString) {
    if (iconString == null || iconString.isEmpty) {
      return IconlyBold.tick_square;
    }

    // Map string names to Iconly icons
    final Map<String, IconData> iconMap = {
      'video': IconlyBold.video,
      'download': IconlyBold.download,
      'access': IconlyBold.time_circle,
      'certificate': IconlyBold.tick_square,
      'book': IconlyBold.bookmark,
      'file': IconlyBold.document,
      'calendar': IconlyBold.calendar,
      'message': IconlyBold.message,
      'notification': IconlyBold.notification,
      'star': IconlyBold.star,
      'heart': IconlyBold.heart,
      'check': IconlyBold.tick_square,
      'play': IconlyBold.play,
      'volume': IconlyBold.volume_up,
      'camera': IconlyBold.camera,
      'image': IconlyBold.image,
      'folder': IconlyBold.folder,
      'home': IconlyBold.home,
      'settings': IconlyBold.setting,
      'search': IconlyBold.search,
      'plus': IconlyBold.plus,
      'close': IconlyBold.close_square,
      'edit': IconlyBold.edit,
      'delete': IconlyBold.delete,
      'share': IconlyBold.send,
      'lock': IconlyBold.lock,
      'unlock': IconlyBold.unlock,
      'eye': IconlyBold.show,
      'hide': IconlyBold.hide,
      'filter': IconlyBold.filter,
      'grid': IconlyBold.category,
      'more': IconlyBold.more_circle,
      'back': IconlyBold.arrow_left,
      'forward': IconlyBold.arrow_right,
      'up': IconlyBold.arrow_up,
      'down': IconlyBold.arrow_down,
    };

    return iconMap[iconString.toLowerCase()] ?? IconlyBold.tick_square;
  }
}
