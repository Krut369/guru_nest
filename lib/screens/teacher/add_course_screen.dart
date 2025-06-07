import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/course_service.dart';

class AddCourseScreen extends StatefulWidget {
  final Map<String, dynamic>? course;

  const AddCourseScreen({
    Key? key,
    this.course,
  }) : super(key: key);

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _courseService = CourseService();
  final _supabase = Supabase.instance.client;
  XFile? _imageFile;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  String? _selectedCategory;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();

    // Initialize form if editing existing course
    if (widget.course != null) {
      _titleController.text = widget.course!['title'] ?? '';
      _descriptionController.text = widget.course!['description'] ?? '';
      _priceController.text = widget.course!['price']?.toString() ?? '';
      _selectedCategory = widget.course!['category_id']?.toString();
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoadingCategories = true;
      });

      final response =
          await _supabase.from('categories').select().order('name');

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
          _isLoadingCategories = false;
        });
      }
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

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
          price: double.parse(_priceController.text),
          categoryId: _selectedCategory!,
          imageBytes: _imageBytes,
          teacherId: user.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course created successfully')),
          );
          Navigator.pop(context, true);
        }
      } else {
        // EDIT MODE
        // Only update fields that have changed
        final String courseId = widget.course!['id'];
        String? newTitle = _titleController.text != widget.course!['title']
            ? _titleController.text
            : null;
        String? newDescription =
            _descriptionController.text != widget.course!['description']
                ? _descriptionController.text
                : null;
        double? newPrice = double.tryParse(_priceController.text) != null &&
                double.parse(_priceController.text) !=
                    (widget.course!['price'] is String
                        ? double.parse(widget.course!['price'])
                        : widget.course!['price'])
            ? double.parse(_priceController.text)
            : null;
        String? newCategoryId =
            _selectedCategory != widget.course!['category_id']?.toString()
                ? _selectedCategory
                : null;
        // For image, only update if a new image is picked
        File? imageFile;
        if (_imageFile != null) {
          imageFile = File(_imageFile!.path);
        }
        await _courseService.updateCourse(
          courseId: courseId,
          title: newTitle,
          description: newDescription,
          price: newPrice,
          categoryId: newCategoryId,
          imageFile: imageFile,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course updated successfully')),
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
                  : 'Error updating course: $e')),
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

  @override
  Widget build(BuildContext context) {
    final BoxDecoration glassBlueCardDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          AppTheme.primaryBlue.withOpacity(0.03),
          AppTheme.primaryBlue.withOpacity(0.05),
        ],
        stops: const [0.0, 0.6, 1.0],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course == null ? 'Add New Course' : 'Edit Course',
            style: const TextStyle(color: Colors.white)),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course Image
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      image: _imageBytes != null
                          ? DecorationImage(
                              image: MemoryImage(_imageBytes!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _imageBytes == null
                        ? const Icon(
                            Icons.add_photo_alternate,
                            size: 50,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // All form fields and button in one glass blue card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.transparent,
                child: Container(
                  decoration: glassBlueCardDecoration,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Course Title',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a course title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Course Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a course description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _isLoadingCategories
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                              items: _categories.map((category) {
                                return DropdownMenuItem<String>(
                                  value: category['id'].toString(),
                                  child: Text(category['name'] as String),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedCategory = newValue;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a category';
                                }
                                return null;
                              },
                              dropdownColor: Colors.white,
                            ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          border: OutlineInputBorder(),
                          prefixText: '\$',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a price';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: AppTheme.primaryBlueDark,
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Text(
                                  widget.course == null
                                      ? 'Create Course'
                                      : 'Save Changes',
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<Map<String, dynamic>> _loadQuizStats(String quizId) async {
  try {
    final results = await Supabase.instance.client
        .from('quiz_results')
        .select('score')
        .eq('quiz_id', quizId);

    if (results.isEmpty) {
      return {
        'averageScore': 0.0,
        'totalAttempts': 0,
        'highestScore': 0.0,
      };
    }

    final scores = results.map<num>((r) => (r['score'] as num?) ?? 0).toList();
    final totalAttempts = scores.length;
    final averageScore = scores.isNotEmpty
        ? scores.reduce((a, b) => a + b) / scores.length
        : 0.0;
    final highestScore =
        scores.isNotEmpty ? scores.reduce((a, b) => a > b ? a : b) : 0.0;

    return {
      'averageScore': averageScore,
      'totalAttempts': totalAttempts,
      'highestScore': highestScore,
    };
  } catch (e) {
    print('Exception in loadQuizStats: $e');
    return {
      'averageScore': 0.0,
      'totalAttempts': 0,
      'highestScore': 0.0,
    };
  }
}
