import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';

class EditQuizScreen extends StatefulWidget {
  final String quizId;
  final String courseId;
  final Map<String, dynamic> quizData;

  const EditQuizScreen({
    super.key,
    required this.quizId,
    required this.courseId,
    required this.quizData,
  });

  @override
  State<EditQuizScreen> createState() => _EditQuizScreenState();
}

class _EditQuizScreenState extends State<EditQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.quizData['title']);
    _descriptionController =
        TextEditingController(text: widget.quizData['description']);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateQuiz() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.from('quizzes').update({
        'title': _titleController.text,
        'description': _descriptionController.text,
      }).eq('id', widget.quizId);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e, stack) {
      print('Exception in updateQuiz: $e');
      print('Stack trace: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating quiz: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Glass blue gradient for cards (matches quiz management)
    BoxDecoration glassBlueCardDecoration = BoxDecoration(
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
        title: const Text('Edit Quiz'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: 'Quiz Title',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a description';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _updateQuiz,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Update Quiz'),
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
