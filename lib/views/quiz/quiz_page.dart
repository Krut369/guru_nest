import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Import go_router for navigation
import 'package:guru_nest/services/auth_service.dart'; // Import AuthService
import 'package:guru_nest/services/course_service.dart';

import '../../core/theme/app_theme.dart';
import '../../models/question_model.dart';
import '../../models/quiz_option_model.dart';

class QuizPage extends StatefulWidget {
  final String quizId;

  const QuizPage({super.key, required this.quizId});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late Future<Map<String, dynamic>> _quizDataFuture;
  final CourseService _courseService = CourseService();
  final AuthService _authService = AuthService(); // Instantiate AuthService
  // Map to store selected options for multiple choice questions
  final Map<String, String?> _selectedOptions = {};
  // Map to store text answers for text-based questions
  final Map<String, String> _textAnswers = {};
  bool _isSubmitting = false;
  bool _hasTakenQuiz = false;
  double? _previousScore;

  @override
  void initState() {
    super.initState();
    _quizDataFuture =
        _courseService.fetchQuizWithQuestionsAndOptions(widget.quizId);
    _checkQuizStatus();
  }

  Future<void> _checkQuizStatus() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final hasTaken =
            await _courseService.hasStudentTakenQuiz(widget.quizId, user.id);
        if (hasTaken) {
          final results = await _courseService.getStudentQuizResults(user.id);
          final quizResult = results.firstWhere(
            (result) => result['quiz_id'] == widget.quizId,
            orElse: () => {'score': 0.0},
          );
          setState(() {
            _hasTakenQuiz = true;
            _previousScore = quizResult['score']?.toDouble();
          });
        }
      }
    } catch (e) {
      print('Error checking quiz status: $e');
    }
  }

  void _handleOptionSelect(String questionId, String optionId) {
    setState(() {
      _selectedOptions[questionId] = optionId;
    });
  }

  void _handleTextAnswer(String questionId, String answer) {
    setState(() {
      _textAnswers[questionId] = answer;
    });
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) {
        // Handle case where user is not logged in
        print('User not logged in. Cannot submit quiz.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to submit the quiz.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      final quizData = await _quizDataFuture;
      final questions = (quizData['quiz_questions'] as List)
          .map((q) => Question.fromJson(q))
          .toList();

      if (questions.isEmpty) {
        print('No questions loaded. Cannot submit quiz.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load quiz questions.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      double score = 0;
      int correctAnswers = 0;
      int totalQuestions = questions.length;

      for (var question in questions) {
        if (question.questionType == 'text') {
          // Handle text-based question
          final textAnswer = _textAnswers[question.id]?.trim().toLowerCase();
          if (textAnswer != null && textAnswer.isNotEmpty) {
            final options = (quizData['quiz_questions'] as List)
                    .firstWhere((q) => q['id'] == question.id)['quiz_options']
                as List;
            final correctOption =
                options.firstWhere((opt) => opt['is_correct'] == true);
            if (textAnswer ==
                correctOption['option_text'].toString().toLowerCase()) {
              correctAnswers++;
            }
          }
        } else {
          // Handle multiple choice question
          final selectedOptionId = _selectedOptions[question.id];
          if (selectedOptionId != null) {
            final options = (quizData['quiz_questions'] as List)
                    .firstWhere((q) => q['id'] == question.id)['quiz_options']
                as List;
            final correctOption =
                options.firstWhere((opt) => opt['is_correct'] == true);
            if (selectedOptionId == correctOption['id']) {
              correctAnswers++;
            }
          }
        }
      }

      score = (correctAnswers / totalQuestions) * 100;

      print('Quiz submitted. Score: ${score.toStringAsFixed(2)}%');

      // Save the quiz result
      await _courseService.saveQuizResult(
        quizId: widget.quizId,
        studentId: user.id,
        score: score,
      );

      // TODO: Navigate to a results page or show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Quiz submitted successfully! Your score: ${score.toStringAsFixed(2)}%'),
          backgroundColor: AppTheme.successGreen,
        ),
      );

      // Optional: Navigate back after submission or to a results page
      if (context.mounted) {
        // context.go('/quiz_result/${resultId}'); // If you have a results page
        context.pop(); // Go back to lesson detail
      }
    } catch (e) {
      print('Error submitting quiz: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting quiz: ${e.toString()}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Widget _buildQuestionInput(Question question, Map<String, dynamic> quizData) {
    if (question.questionType == 'text') {
      return TextField(
        decoration: InputDecoration(
          hintText: 'Enter your answer',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (value) => _handleTextAnswer(question.id, value),
        maxLines: 3,
        controller: TextEditingController(text: _textAnswers[question.id]),
      );
    } else {
      final options = (quizData['quiz_questions'] as List)
          .firstWhere((q) => q['id'] == question.id)['quiz_options'] as List;

      return Column(
        children: options.map((option) {
          final quizOption = QuizOption.fromJson(option);
          return RadioListTile<String>(
            title: Text(quizOption.optionText),
            value: quizOption.id,
            groupValue: _selectedOptions[question.id],
            onChanged: (value) {
              if (value != null) {
                _handleOptionSelect(question.id, value);
              }
            },
          );
        }).toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
      ),
      body: _hasTakenQuiz
          ? _buildQuizResult()
          : FutureBuilder<Map<String, dynamic>>(
              future: _quizDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                      child: Text('Error loading quiz: ${snapshot.error}'));
                } else if (!snapshot.hasData) {
                  return const Center(child: Text('No quiz data available.'));
                }

                final quizData = snapshot.data!;
                final questions = (quizData['quiz_questions'] as List)
                    .map((q) => Question.fromJson(q))
                    .toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.defaultPadding),
                  itemCount: questions.length + 1,
                  itemBuilder: (context, index) {
                    if (index < questions.length) {
                      final question = questions[index];
                      return Card(
                        margin: const EdgeInsets.only(
                            bottom: AppTheme.defaultSpacing),
                        child: Padding(
                          padding:
                              const EdgeInsets.all(AppTheme.defaultPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Question ${index + 1}: ${question.questionText}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: AppTheme.defaultSpacing),
                              _buildQuestionInput(question, quizData),
                            ],
                          ),
                        ),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.defaultPadding),
                        child: Center(
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitQuiz,
                            child: _isSubmitting
                                ? const CircularProgressIndicator()
                                : const Text('Submit Quiz'),
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
    );
  }

  Widget _buildQuizResult() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(AppTheme.defaultPadding),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.defaultPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: AppTheme.successGreen,
                size: 64,
              ),
              const SizedBox(height: AppTheme.defaultSpacing),
              Text(
                'You have already taken this quiz',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.smallSpacing),
              Text(
                'Your score: ${_previousScore?.toStringAsFixed(2)}%',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.defaultSpacing),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
