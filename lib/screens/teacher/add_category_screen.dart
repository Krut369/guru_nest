import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';

class AddCategoryScreen extends StatefulWidget {
  final Map<String, dynamic>? category;

  const AddCategoryScreen({
    Key? key,
    this.category,
  }) : super(key: key);

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _supabase = Supabase.instance.client;
  XFile? _iconFile;
  String? _currentIconUrl;
  bool _isLoading = false;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!['name'];
      _currentIconUrl = widget.category!['icon_url'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _iconFile = pickedFile;
          _imageBytes = bytes;
          _currentIconUrl = null;
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

  Future<String?> _uploadIcon() async {
    if (_iconFile == null) return _currentIconUrl;

    try {
      // First check if bucket exists
      try {
        await _supabase.storage.from('categories').list();
      } catch (e) {
        throw Exception(
            'Categories bucket does not exist. Please create it in Supabase storage first.');
      }

      final fileExt = _iconFile!.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'categories/$fileName';

      // Read file bytes
      final bytes = await _iconFile!.readAsBytes();

      // Upload file
      await _supabase.storage.from('categories').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      return _supabase.storage.from('categories').getPublicUrl(filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? iconUrl;
      if (_iconFile != null) {
        iconUrl = await _uploadIcon();
        if (iconUrl == null) {
          throw Exception('Failed to upload icon');
        }
      } else {
        iconUrl = _currentIconUrl;
      }

      final data = {
        'name': _nameController.text.trim(),
        'icon_url': iconUrl,
      };

      if (widget.category != null) {
        await _supabase
            .from('categories')
            .update(data)
            .eq('id', widget.category!['id']);
      } else {
        await _supabase.from('categories').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.category != null
                ? 'Category updated successfully'
                : 'Category added successfully'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error ${widget.category != null ? 'updating' : 'adding'} category: $e'),
            backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category != null ? 'Edit Category' : 'Add Category',
            style: const TextStyle(color: Colors.white)),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
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
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickIcon,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          image: _imageBytes != null
                              ? DecorationImage(
                                  image: MemoryImage(_imageBytes!),
                                  fit: BoxFit.cover,
                                )
                              : _currentIconUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_currentIconUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        child: _iconFile == null && _currentIconUrl == null
                            ? const Icon(
                                Icons.add_photo_alternate,
                                size: 40,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Category Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlueDark,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a category name';
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
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              widget.category != null
                                  ? 'Update Category'
                                  : 'Add Category',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
