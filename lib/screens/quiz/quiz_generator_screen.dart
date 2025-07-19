import 'package:flutter/material.dart';

import '../../models/quiz_model.dart';
import '../../services/quiz_service.dart';

class QuizGeneratorScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const QuizGeneratorScreen({
    Key? key,
    required this.courseId,
    required this.courseTitle,
  }) : super(key: key);

  @override
  _QuizGeneratorScreenState createState() => _QuizGeneratorScreenState();
}

class _QuizGeneratorScreenState extends State<QuizGeneratorScreen> {
  final QuizService _quizService = QuizService();
  List<GeneratedQuizQuestion>? _questions;
  bool _isLoading = false;
  String? _error;
  final _titleController = TextEditingController();
  final _numberOfQuestionsController = TextEditingController(text: '5');
  String _selectedDifficulty = 'intermediate';

  Future<void> _generateQuiz() async {
    if (_titleController.text.isEmpty) {
      setState(() {
        _error = 'Please enter a quiz title';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final quizData = await _quizService.generateQuiz(
        topic: widget.courseTitle,
        numberOfQuestions: int.parse(_numberOfQuestionsController.text),
        difficulty: _selectedDifficulty,
      );

      setState(() {
        _questions =
            quizData.map((q) => GeneratedQuizQuestion.fromJson(q)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveQuiz() async {
    if (_questions == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _quizService.saveQuiz(
        courseId: widget.courseId,
        title: _titleController.text,
        questions: _questions!.map((q) => q.toJson()).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz saved successfully')),
        );
        Navigator.pop(context);
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
      appBar: AppBar(
        title: const Text('Generate Quiz'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Quiz Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _numberOfQuestionsController,
                    decoration: const InputDecoration(
                      labelText: 'Number of Questions',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedDifficulty,
                    decoration: const InputDecoration(
                      labelText: 'Difficulty',
                      border: OutlineInputBorder(),
                    ),
                    items: ['easy', 'intermediate', 'hard']
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text(d.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedDifficulty = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _questions == null ? _generateQuiz : _saveQuiz,
                    child: Text(
                        _questions == null ? 'Generate Quiz' : 'Save Quiz'),
                  ),
                  if (_questions != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Generated Questions:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._questions!.asMap().entries.map(
                          (entry) => Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Question ${entry.key + 1}:',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(entry.value.question),
                                  const SizedBox(height: 16),
                                  ...entry.value.options.asMap().entries.map(
                                        (option) => RadioListTile(
                                          title: Text(option.value),
                                          value: option.key,
                                          groupValue: entry.value.correctAnswer,
                                          onChanged: null,
                                        ),
                                      ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Explanation: ${entry.value.explanation}',
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _numberOfQuestionsController.dispose();
    super.dispose();
  }
}
