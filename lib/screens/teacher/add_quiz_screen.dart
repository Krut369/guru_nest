import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/theme/app_theme.dart';

class AddQuizScreen extends StatefulWidget {
  final String courseId;

  const AddQuizScreen({
    super.key,
    required this.courseId,
  });

  @override
  State<AddQuizScreen> createState() => _AddQuizScreenState();
}

class _AddQuizScreenState extends State<AddQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _supabase = supabase.Supabase.instance.client;
  bool _isLoading = false;
  bool _isGenerating = false;
  String? _error;

  final List<Map<String, dynamic>> _questions = [];
  final _questionController = TextEditingController();
  final _optionControllers = List.generate(4, (_) => TextEditingController());
  int _correctOptionIndex = 0;

  List<Map<String, dynamic>> _lessons = [];
  String? _selectedLessonId;
  bool _isLessonsLoading = false;

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

  @override
  void initState() {
    super.initState();
    _fetchLessons();
  }

  Future<void> _fetchLessons() async {
    setState(() {
      _isLessonsLoading = true;
    });
    try {
      final lessons = await _supabase
          .from('lessons')
          .select('id, title')
          .eq('course_id', widget.courseId)
          .order('title');
      setState(() {
        _lessons = List<Map<String, dynamic>>.from(lessons);
        if (_lessons.isNotEmpty) {
          _selectedLessonId = _lessons.first['id'] as String;
        }
      });
    } catch (e) {
      // Handle error if needed
    } finally {
      setState(() {
        _isLessonsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _generateAIMCQ() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a quiz title first'),
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

      // Call the AI function to generate MCQs
      final response = await _supabase.functions.invoke(
        'generate-mcq',
        body: {
          'course_title': courseTitle,
          'quiz_title': _titleController.text,
          'description': _descriptionController.text,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to generate questions: ${response.data}');
      }

      final generatedQuestions =
          List<Map<String, dynamic>>.from(response.data['questions']).map((q) {
        // Ensure options have the correct types
        final options = List<Map<String, dynamic>>.from(q['options'])
            .map((opt) => {
                  'text': opt['text'] as String,
                  'is_correct': opt['is_correct'] as bool,
                })
            .toList();

        return {
          'question': q['question'] as String,
          'options': options,
        };
      }).toList();

      setState(() {
        _questions.addAll(generatedQuestions);
        _isGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated ${generatedQuestions.length} questions'),
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
            content: Text('Error generating questions: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _addQuestion() {
    if (_questionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a question'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    final options = _optionControllers.map((c) => c.text).toList();
    if (options.any((option) => option.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all options'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _questions.add({
        'question': _questionController.text,
        'options': List.generate(
            options.length,
            (index) => {
                  'text': options[index],
                  'is_correct': index == _correctOptionIndex
                }),
      });
      _questionController.clear();
      for (var controller in _optionControllers) {
        controller.clear();
      }
      _correctOptionIndex = 0;
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  Future<void> _saveQuiz() async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one question'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // First, create the quiz
      final quiz = await _supabase
          .from('quizzes')
          .insert({
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'course_id': widget.courseId,
            'lesson_id': _selectedLessonId,
          })
          .select()
          .single();

      // Then, create the questions and their options
      for (var question in _questions) {
        // Create the question
        final questionResponse = await _supabase
            .from('quiz_questions')
            .insert({
              'quiz_id': quiz['id'],
              'question_text': question['question'],
              'question_type': 'mcq',
            })
            .select()
            .single();

        // Create the options
        final options = question['options'] as List;
        for (var i = 0; i < options.length; i++) {
          await _supabase.from('quiz_options').insert({
            'question_id': questionResponse['id'],
            'option_text': options[i]['text'],
            'is_correct': options[i]['is_correct'],
          });
        }
      }

      if (mounted) {
        Navigator.pop(context, quiz);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text('Add Quiz',
            style: Theme.of(context)
                .textTheme
                .displayMedium
                ?.copyWith(color: Colors.white)),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                  margin: const EdgeInsets.only(bottom: 24),
                  color: Colors.transparent,
                  child: Container(
                    decoration: glassBlueCardDecoration,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quiz Details',
                              style: Theme.of(context).textTheme.displayMedium),
                          const SizedBox(height: 16),
                          if (_isLessonsLoading)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: LinearProgressIndicator(),
                            ),
                          if (_lessons.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: DropdownButtonFormField<String>(
                                value: _selectedLessonId,
                                decoration: const InputDecoration(
                                  labelText: 'Select Lesson',
                                  border: OutlineInputBorder(),
                                  filled: true,
                                ),
                                items: _lessons
                                    .map((lesson) => DropdownMenuItem<String>(
                                          value: lesson['id'] as String,
                                          child:
                                              Text(lesson['title'] as String),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedLessonId = value;
                                  });
                                },
                                validator: (value) => value == null
                                    ? 'Please select a lesson'
                                    : null,
                              ),
                            ),
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Quiz Title',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.85),
                            ),
                            style: Theme.of(context).textTheme.bodyLarge,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a quiz title';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.85),
                            ),
                            style: Theme.of(context).textTheme.bodyLarge,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.only(bottom: 24),
                  color: Colors.transparent,
                  child: Container(
                    decoration: glassBlueCardDecoration,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Add Question',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow
                                      .ellipsis, // Optional: prevents text overflow
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed:
                                    _isGenerating ? null : _generateAIMCQ,
                                icon: _isGenerating
                                    ? const SizedBox(
                                        width: double.infinity,
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
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _questionController,
                            decoration: InputDecoration(
                              labelText: 'Question',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.85),
                            ),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(4, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  Radio<int>(
                                    value: index,
                                    groupValue: _correctOptionIndex,
                                    onChanged: (value) {
                                      setState(() {
                                        _correctOptionIndex = value!;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _optionControllers[index],
                                      decoration: InputDecoration(
                                        labelText: 'Option ${index + 1}',
                                        border: const OutlineInputBorder(),
                                        filled: true,
                                        fillColor:
                                            Colors.white.withOpacity(0.85),
                                      ),
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _addQuestion,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Question'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlueDark,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_questions.isNotEmpty) ...[
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: const EdgeInsets.only(bottom: 24),
                    color: Colors.transparent,
                    child: Container(
                      decoration: glassBlueCardDecoration,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Added Questions',
                                style:
                                    Theme.of(context).textTheme.displayMedium),
                            const SizedBox(height: 16),
                            ...List.generate(_questions.length, (index) {
                              final question = _questions[index];
                              String correctAnswer = '';
                              try {
                                final options = List<Map<String, dynamic>>.from(
                                    question['options']);
                                final correct = options.firstWhere(
                                  (opt) => opt['is_correct'] == true,
                                  orElse: () => <String, dynamic>{},
                                );
                                if (correct['text'] != null) {
                                  correctAnswer = correct['text'].toString();
                                } else {
                                  correctAnswer = 'N/A';
                                }
                              } catch (e) {
                                correctAnswer = 'N/A';
                              }
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                color: Colors.transparent,
                                child: Container(
                                  decoration: glassBlueCardDecoration,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                question['question'],
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete),
                                              onPressed: () =>
                                                  _removeQuestion(index),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Correct answer: $correctAnswer',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                  color: AppTheme.primaryBlue,
                                                  fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppTheme.errorRed),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlueDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Create Quiz',
                            style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
