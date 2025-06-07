import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';

class QuizQuestionsScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const QuizQuestionsScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<QuizQuestionsScreen> createState() => _QuizQuestionsScreenState();
}

class _QuizQuestionsScreenState extends State<QuizQuestionsScreen> {
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);

    try {
      final questions = await Supabase.instance.client
          .from('quiz_questions')
          .select('*')
          .eq('quiz_id', widget.quizId);

      setState(() {
        _questions = List<Map<String, dynamic>>.from(questions);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteQuestion(String questionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text(
            'Are you sure you want to delete this question? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('quiz_questions')
            .delete()
            .eq('id', questionId);
        _loadQuestions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting question: $e'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Glass blue gradient for cards (matches quiz management)
    BoxDecoration glassBlueCardDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(12),
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
        title: Text('Questions - ${widget.quizTitle}'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Navigate to add question screen
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    'Error: $_error',
                    style: const TextStyle(color: AppTheme.errorRed),
                  ),
                )
              : _questions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.question_mark,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No questions found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Navigate to add question screen
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Question'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        final question = _questions[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: Colors.transparent,
                          child: Container(
                            decoration: glassBlueCardDecoration,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Question ${index + 1}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () {
                                              // TODO: Navigate to edit question screen
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            color: AppTheme.errorRed,
                                            onPressed: () =>
                                                _deleteQuestion(question['id']),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        question['question_text'] ??
                                            'No question text',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 16),
                                      if (question['options'] != null) ...[
                                        const Text(
                                          'Options:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...List.generate(
                                          (question['options'] as List).length,
                                          (optionIndex) {
                                            final option = question['options']
                                                [optionIndex];
                                            final isCorrect =
                                                option['is_correct'] == true;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isCorrect
                                                        ? Icons.check_circle
                                                        : Icons.circle_outlined,
                                                    color: isCorrect
                                                        ? Colors.green
                                                        : Colors.grey,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      option['text'] ?? '',
                                                      style: TextStyle(
                                                        color: isCorrect
                                                            ? Colors.green
                                                            : null,
                                                        fontWeight: isCorrect
                                                            ? FontWeight.bold
                                                            : null,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
