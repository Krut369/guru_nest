import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../models/lesson_model.dart';
import '../../services/course_service.dart';

class AddMaterialScreen extends StatefulWidget {
  final String courseId;

  const AddMaterialScreen({Key? key, required this.courseId}) : super(key: key);

  @override
  State<AddMaterialScreen> createState() => _AddMaterialScreenState();
}

class _AddMaterialScreenState extends State<AddMaterialScreen> {
  final _supabase = Supabase.instance.client;
  final _courseService = CourseService();

  List<Lesson> _lessons = [];
  bool _isLoading = true;
  String? _error;
  Lesson? _selectedLesson;
  bool _isGenerating = false;

  // Text controllers for material details
  final _titleController = TextEditingController();
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // File picking related variables
  final List<PlatformFile> _selectedFiles = [];
  Set<int> _selectedFileIndices = {}; // Track selected file indices

  // Material type selection
  final Map<String, bool> _materialTypes = {
    'document': true,
    'video': false,
    'pdf': false,
    'exercise': false,
  };

  // File upload progress tracking
  Map<int, double> _fileUploadProgress = {};

  @override
  void initState() {
    super.initState();
    _fetchLessons();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _fetchLessons() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _supabase
          .from('lessons')
          .select('*')
          .eq('course_id', widget.courseId)
          .order('lesson_order', ascending: true);

      setState(() {
        _lessons =
            (response as List).map((json) => Lesson.fromJson(json)).toList();
        _isLoading = false;
        if (_lessons.isNotEmpty) {
          _selectedLesson = _lessons.first;
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Error fetching lessons: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: kIsWeb,
      );

      if (result?.files.isNotEmpty ?? false) {
        setState(() {
          // Append new files to the existing list
          _selectedFiles.addAll(result!.files);
          // Add new indices to the selected set
          _selectedFileIndices.addAll(
            List.generate(
              result.files.length,
              (index) => _selectedFiles.length - result.files.length + index,
            ),
          );
        });
      }
    } catch (e) {
      print('File picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveMaterial() async {
    if (_selectedLesson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a lesson'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedFileIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one file'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get selected material types
    final selectedTypes = _materialTypes.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one material type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _fileUploadProgress = {};
    });

    try {
      final selectedFiles =
          _selectedFileIndices.map((index) => _selectedFiles[index]).toList();
      List<String> fileUrls = [];

      for (int i = 0; i < selectedFiles.length; i++) {
        final file = selectedFiles[i];
        final fileIndex = _selectedFiles.indexOf(file);
        String fileUrl;

        // Initialize progress for this file
        setState(() {
          _fileUploadProgress[fileIndex] = 0.0;
        });

        if (kIsWeb) {
          if (file.bytes == null) {
            throw Exception('File data is missing');
          }
          fileUrl = await _courseService.uploadCourseMaterialWeb(
            bytes: file.bytes!,
            fileName: file.name,
            courseId: widget.courseId,
            fileType: _getFileType(file.extension),
            lessonId: _selectedLesson!.id,
            onProgress: (progress) {
              setState(() {
                _fileUploadProgress[fileIndex] = progress;
              });
            },
          );
        } else {
          if (file.path == null) {
            throw Exception('File path is missing');
          }
          final fileObj = File(file.path!);
          if (!await fileObj.exists()) {
            throw Exception('Selected file does not exist');
          }
          fileUrl = await _courseService.uploadCourseMaterial(
            file: fileObj,
            courseId: widget.courseId,
            fileType: _getFileType(file.extension),
            lessonId: _selectedLesson!.id,
            onProgress: (progress) {
              setState(() {
                _fileUploadProgress[fileIndex] = progress;
              });
            },
          );
        }

        fileUrls.add(fileUrl);

        // Update overall progress
        setState(() {
          _uploadProgress = (i + 1) / selectedFiles.length;
        });
      }

      // Create material records for each file
      for (int i = 0; i < fileUrls.length; i++) {
        final fileUrl = fileUrls[i];
        final fileType = _getFileType(fileUrl.split('.').last);

        // Create a material record for each file
        await _supabase.from('materials').insert({
          'lesson_id': _selectedLesson!.id,
          'title':
              '${_titleController.text}${fileUrls.length > 1 ? ' (${i + 1})' : ''}',
          'type': fileType,
          'file_url': fileUrl,
          'uploaded_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Material added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving material: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving material: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
          _fileUploadProgress = {};
        });
      }
    }
  }

  Future<void> _generateAIMaterial() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a material title first'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      // Get the course title
      final courseData = await _supabase
          .from('courses')
          .select('title')
          .eq('id', widget.courseId)
          .single();

      final courseTitle = courseData['title'] as String;

      // Call the AI function to generate material
      final response = await _supabase.functions.invoke(
        'generate-material',
        body: {
          'course_title': courseTitle,
          'material_title': _titleController.text,
          'lesson_title': _selectedLesson?.title,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to generate material: ${response.data}');
      }

      final generatedContent = response.data['content'] as String;

      setState(() {
        _isGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Material generated successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating material: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  String _getFileType(String? extension) {
    if (extension == null) return 'document';

    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'pdf';
      case 'mp4':
      case 'avi':
      case 'mov':
        return 'video';
      case 'doc':
      case 'docx':
      case 'xls':
      case 'xlsx':
      case 'ppt':
      case 'pptx':
        return 'document';
      default:
        return 'document';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Material'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Lesson',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.defaultSpacing),
                      if (_lessons.isEmpty)
                        const Text('No lessons available for this course.'),
                      if (_lessons.isNotEmpty)
                        DropdownButtonFormField<Lesson>(
                          value: _selectedLesson,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 15),
                          ),
                          items: _lessons.map((lesson) {
                            return DropdownMenuItem<Lesson>(
                              value: lesson,
                              child: Text(lesson.title),
                            );
                          }).toList(),
                          onChanged: (Lesson? newValue) {
                            setState(() {
                              _selectedLesson = newValue;
                            });
                          },
                        ),

                      const SizedBox(height: AppTheme.defaultSpacing * 2),

                      const Text(
                        'Material Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.defaultSpacing),

                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Material Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppTheme.defaultSpacing),

                      // Add Generate with AI button
                      ElevatedButton.icon(
                        onPressed: _isGenerating ? null : _generateAIMaterial,
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(_isGenerating
                            ? 'Generating...'
                            : 'Generate with AI'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppTheme.defaultSpacing),

                      // Material Type Selection
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Material Type',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 16,
                                runSpacing: 12,
                                children: _materialTypes.entries.map((entry) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: entry.value,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            _materialTypes[entry.key] =
                                                value ?? false;
                                          });
                                        },
                                      ),
                                      Text(
                                        entry.key.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.defaultSpacing),

                      // File picker button and selected files display
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isUploading ? null : _pickAndUploadFile,
                            icon: const Icon(Icons.attach_file),
                            label: const Text('Pick Files'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          if (_selectedFiles.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _selectedFiles.length,
                                itemBuilder: (context, index) {
                                  final file = _selectedFiles[index];
                                  final isUploading = _isUploading &&
                                      _selectedFileIndices.contains(index);
                                  final uploadProgress =
                                      _fileUploadProgress[index] ?? 0.0;

                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey[300]!,
                                          width:
                                              index < _selectedFiles.length - 1
                                                  ? 1
                                                  : 0,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        ListTile(
                                          leading: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Checkbox(
                                                value: _selectedFileIndices
                                                    .contains(index),
                                                onChanged: _isUploading
                                                    ? null
                                                    : (bool? value) {
                                                        setState(() {
                                                          if (value == true) {
                                                            _selectedFileIndices
                                                                .add(index);
                                                          } else {
                                                            _selectedFileIndices
                                                                .remove(index);
                                                          }
                                                        });
                                                      },
                                              ),
                                              Icon(
                                                _getFileIcon(file.extension),
                                                color: AppTheme.primaryBlue,
                                              ),
                                            ],
                                          ),
                                          title: Text(
                                            file.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${(file.size / 1024).toStringAsFixed(2)} KB',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                              color: Colors.red,
                                            ),
                                            onPressed: _isUploading
                                                ? null
                                                : () {
                                                    setState(() {
                                                      _selectedFiles
                                                          .removeAt(index);
                                                      _selectedFileIndices
                                                          .remove(index);
                                                      // Adjust indices after removal
                                                      _selectedFileIndices =
                                                          _selectedFileIndices
                                                              .map((i) =>
                                                                  i > index
                                                                      ? i - 1
                                                                      : i)
                                                              .toSet();
                                                    });
                                                  },
                                          ),
                                        ),
                                        if (isUploading)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                16, 0, 16, 8),
                                            child: Column(
                                              children: [
                                                LinearProgressIndicator(
                                                  value: uploadProgress,
                                                  backgroundColor:
                                                      Colors.grey[200],
                                                  valueColor:
                                                      const AlwaysStoppedAnimation<
                                                              Color>(
                                                          AppTheme.primaryBlue),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    const Icon(
                                                      Icons.upload_file,
                                                      color:
                                                          AppTheme.primaryBlue,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${(uploadProgress * 100).toStringAsFixed(1)}%',
                                                      style: const TextStyle(
                                                        color: AppTheme
                                                            .primaryBlue,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          if (_isUploading) ...[
                            const SizedBox(height: 16),
                            LinearProgressIndicator(
                              value: _uploadProgress,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryBlue),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.upload_file,
                                  color: AppTheme.primaryBlue,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Uploading: ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: AppTheme.defaultSpacing * 2),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isUploading ? null : _saveMaterial,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isUploading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Uploading: ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                )
                              : const Text('Save Material'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }
}
