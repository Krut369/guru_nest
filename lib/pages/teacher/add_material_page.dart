import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';

class AddMaterialPage extends StatefulWidget {
  final String courseId;
  final String lessonId;

  const AddMaterialPage({
    super.key,
    required this.courseId,
    required this.lessonId,
  });

  @override
  State<AddMaterialPage> createState() => _AddMaterialPageState();
}

class _AddMaterialPageState extends State<AddMaterialPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final bool _isLoading = false;
  String? _error;
  List<PlatformFile> _selectedFiles = [];
  Set<int> _selectedFileIndices = {};
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        setState(() {
          _selectedFiles = result.files;
          _selectedFileIndices =
              Set.from(List.generate(_selectedFiles.length, (index) => index));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _uploadFiles() async {
    if (_selectedFileIndices.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final supabaseClient = supabase.Supabase.instance.client;
      final List<String> uploadedFileUrls = [];
      final selectedFiles =
          _selectedFileIndices.map((index) => _selectedFiles[index]).toList();

      for (int i = 0; i < selectedFiles.length; i++) {
        final file = selectedFiles[i];
        final fileExt = file.extension ?? '';
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';
        final filePath =
            'materials/${widget.courseId}/${widget.lessonId}/$fileName';

        // Upload file to Supabase Storage
        await supabaseClient.storage.from('materials').uploadBinary(
              filePath,
              file.bytes!,
              fileOptions: supabase.FileOptions(
                contentType: file.extension == 'pdf' ? 'application/pdf' : null,
              ),
            );

        // Get the public URL
        final fileUrl =
            supabaseClient.storage.from('materials').getPublicUrl(filePath);
        uploadedFileUrls.add(fileUrl);

        // Update progress
        setState(() {
          _uploadProgress = (i + 1) / selectedFiles.length;
        });
      }

      // Create material record with file URLs
      await supabaseClient.from('materials').insert({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'lesson_id': widget.lessonId,
        'course_id': widget.courseId,
        'file_urls': uploadedFileUrls,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Material and files uploaded successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading files: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFileIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one file'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    await _uploadFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Add Material'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title Section
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
                        'Material Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          hintText: 'Enter material title',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          hintText: 'Enter material description',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.description),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // File Selection Section
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
                      Row(
                        children: [
                          const Icon(
                            Icons.attach_file,
                            color: AppTheme.primaryBlue,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Files',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          const Spacer(),
                          if (_selectedFiles.isNotEmpty)
                            TextButton(
                              onPressed: _isUploading ? null : _pickFiles,
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryBlue,
                              ),
                              child: const Text('Add More'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            if (_selectedFiles.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.cloud_upload,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No files selected',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed:
                                          _isUploading ? null : _pickFiles,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryBlue,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                      ),
                                      child: const Text('Select Files'),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _selectedFiles.length,
                                itemBuilder: (context, index) {
                                  final file = _selectedFiles[index];
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
                                    child: ListTile(
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
                                                  _selectedFileIndices =
                                                      _selectedFileIndices
                                                          .map((i) => i > index
                                                              ? i - 1
                                                              : i)
                                                          .toSet();
                                                });
                                              },
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
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
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.errorRed),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.errorRed,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppTheme.errorRed),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading || _isUploading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading || _isUploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Uploading...',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save),
                          SizedBox(width: 8),
                          Text(
                            'Save Material',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
              ),
            ],
          ),
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
