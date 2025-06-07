import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/question_model.dart';
import '../../models/quiz_model.dart';
import '../../models/quiz_option_model.dart';
import '../../services/auth_service.dart';
import '../../services/course_service.dart';

class QuizPage extends StatefulWidget {
  final String quizId;

  const QuizPage({super.key, required this.quizId});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> with TickerProviderStateMixin {
  late Future<Map<String, dynamic>> _quizDataFuture;
  final CourseService _courseService = CourseService();
  final AuthService _authService = AuthService();

  // Quiz state
  final Map<String, String?> _selectedOptions = {};
  final Map<String, String> _textAnswers = {};
  bool _isSubmitting = false;
  bool _hasTakenQuiz = false;
  double? _previousScore;
  int _currentQuestionIndex = 0;
  bool _showResults = false;
  double? _finalScore;
  int _correctAnswers = 0;
  int _totalQuestions = 0;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _quizDataFuture =
        _courseService.fetchQuizWithQuestionsAndOptions(widget.quizId);
    _checkQuizStatus();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
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

  void _nextQuestion() {
    if (_currentQuestionIndex < _totalQuestions - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _slideController.reset();
      _slideController.forward();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
      _slideController.reset();
      _slideController.forward();
    }
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) {
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

      // Check if quiz data is valid
      if (!quizData.containsKey('quiz_questions')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid quiz data.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      final questions = (quizData['quiz_questions'] as List)
          .map((q) => Question.fromJson(q))
          .toList();

      if (questions.isEmpty) {
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
        try {
          if (question.questionType == 'short_answer') {
            final textAnswer = _textAnswers[question.id]?.trim().toLowerCase();
            if (textAnswer != null && textAnswer.isNotEmpty) {
              final questionsList = quizData['quiz_questions'] as List;
              final questionData = questionsList.firstWhere(
                (q) => q['id'] == question.id,
                orElse: () => <String, dynamic>{},
              );

              if (questionData.isNotEmpty &&
                  questionData.containsKey('quiz_options')) {
                final options = questionData['quiz_options'] as List;
                final correctOption = options.firstWhere(
                  (opt) => opt['is_correct'] == true,
                  orElse: () => <String, dynamic>{},
                );

                if (correctOption.isNotEmpty &&
                    textAnswer ==
                        correctOption['option_text'].toString().toLowerCase()) {
                  correctAnswers++;
                }
              }
            }
          } else {
            // Handle MCQ and true_false questions
            final selectedOptionId = _selectedOptions[question.id];
            if (selectedOptionId != null) {
              final questionsList = quizData['quiz_questions'] as List;
              final questionData = questionsList.firstWhere(
                (q) => q['id'] == question.id,
                orElse: () => <String, dynamic>{},
              );

              if (questionData.isNotEmpty &&
                  questionData.containsKey('quiz_options')) {
                final options = questionData['quiz_options'] as List;
                final correctOption = options.firstWhere(
                  (opt) => opt['is_correct'] == true,
                  orElse: () => <String, dynamic>{},
                );

                if (correctOption.isNotEmpty &&
                    selectedOptionId == correctOption['id']) {
                  correctAnswers++;
                }
              }
            }
          }
        } catch (e) {
          print('Error processing question ${question.id}: $e');
          // Continue with other questions
        }
      }

      score = (correctAnswers / totalQuestions) * 100;

      // Save the quiz result
      await _courseService.saveQuizResult(
        quizId: widget.quizId,
        studentId: user.id,
        score: score,
      );

      setState(() {
        _showResults = true;
        _finalScore = score;
        _correctAnswers = correctAnswers;
        _totalQuestions = totalQuestions;
        _isSubmitting = false;
      });

      _fadeController.forward();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting quiz: ${e.toString()}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasTakenQuiz) {
      return _buildQuizResult();
    }

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _quizDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen();
          } else if (snapshot.hasError) {
            return _buildErrorScreen(snapshot.error.toString());
          } else if (!snapshot.hasData || snapshot.data == null) {
            return _buildErrorScreen('No quiz data available.');
          }

          final quizData = snapshot.data!;

          // Check if required data exists
          if (!quizData.containsKey('quiz') ||
              !quizData.containsKey('quiz_questions')) {
            return _buildErrorScreen('Invalid quiz data format.');
          }

          try {
            final quiz = Quiz.fromJson(quizData['quiz']);
            final questions = (quizData['quiz_questions'] as List)
                .map((q) => Question.fromJson(q))
                .toList();

            print('Debug: Parsed ${questions.length} questions');
            print('Debug: Questions data: ${quizData['quiz_questions']}');

            _totalQuestions = questions.length;

            if (_showResults) {
              return _buildResultsScreen();
            }

            return _buildQuizScreen(quiz, questions);
          } catch (e) {
            print('Debug: Error parsing quiz data: $e');
            return _buildErrorScreen('Error parsing quiz data: $e');
          }
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryBlue,
              AppTheme.primaryBlue.withOpacity(0.8),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              SizedBox(height: 24),
              Text(
                'Loading Quiz...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorRed,
              ),
              const SizedBox(height: 16),
              const Text(
                'Error Loading Quiz',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.errorRed,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _quizDataFuture = _courseService
                        .fetchQuizWithQuestionsAndOptions(widget.quizId);
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
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
        ),
      ),
    );
  }

  Widget _buildQuizScreen(Quiz quiz, List<Question> questions) {
    final currentQuestion = questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / questions.length;
    final totalQuestions = questions.length;

    print('Debug: questions.length = $totalQuestions');
    print('Debug: questions type = ${questions.runtimeType}');
    print('Debug: currentQuestionIndex = $_currentQuestionIndex');

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryBlue,
              AppTheme.primaryBlue.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildQuizHeader(quiz, progress),

              // Question Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Question Number and Progress
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.primaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Question ${_currentQuestionIndex + 1} of $totalQuestions',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${((_currentQuestionIndex + 1) / totalQuestions * 100).round()}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Question Text
                            Text(
                              currentQuestion.questionText,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Question Input
                            Expanded(
                              child: _buildQuestionInput(currentQuestion),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Navigation Buttons
              _buildNavigationButtons(questions),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizHeader(Quiz quiz, double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // App Bar
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  quiz.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48), // Balance the back button
            ],
          ),

          const SizedBox(height: 20),

          // Progress Bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionInput(Question question) {
    if (question.questionType == 'short_answer') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Answer',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Type your answer here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primaryBlue, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (value) => _handleTextAnswer(question.id, value),
              maxLines: null,
              expands: true,
              controller:
                  TextEditingController(text: _textAnswers[question.id]),
            ),
          ),
        ],
      );
    } else {
      // Handle MCQ and true_false questions
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.questionType == 'true_false'
                ? 'Select True or False'
                : 'Select an option',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _quizDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data == null) {
                  return Center(
                    child: Text(
                      'Error loading options',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                final quizData = snapshot.data!;

                // Check if quiz_questions exists
                if (!quizData.containsKey('quiz_questions')) {
                  return Center(
                    child: Text(
                      'No questions available',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                try {
                  final questions = quizData['quiz_questions'] as List;
                  final questionData = questions.firstWhere(
                    (q) => q['id'] == question.id,
                    orElse: () => <String, dynamic>{},
                  );

                  if (questionData.isEmpty ||
                      !questionData.containsKey('quiz_options')) {
                    return Center(
                      child: Text(
                        'No options available for this question',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }

                  final options = questionData['quiz_options'] as List;

                  if (options.isEmpty) {
                    return Center(
                      child: Text(
                        'No options available',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      try {
                        final optionData = options[index];

                        // Validate option data before parsing
                        if (optionData == null) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red[300]!),
                            ),
                            child: Text(
                              'Invalid option data (null)',
                              style: TextStyle(color: Colors.red[600]),
                            ),
                          );
                        }

                        if (optionData is! Map<String, dynamic>) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red[300]!),
                            ),
                            child: Text(
                              'Invalid option data format: ${optionData.runtimeType}',
                              style: TextStyle(color: Colors.red[600]),
                            ),
                          );
                        }

                        final quizOption = QuizOption.fromJson(optionData);
                        final isSelected =
                            _selectedOptions[question.id] == quizOption.id;

                        return GestureDetector(
                          onTap: () =>
                              _handleOptionSelect(question.id, quizOption.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryBlue.withOpacity(0.1)
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryBlue
                                    : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? AppTheme.primaryBlue
                                        : Colors.grey[300],
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    quizOption.optionText,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? AppTheme.primaryBlue
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      } catch (e) {
                        print('Error parsing option at index $index: $e');
                        print('Option data: ${options[index]}');
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red[300]!),
                          ),
                          child: Text(
                            'Error loading option: $e',
                            style: TextStyle(color: Colors.red[600]),
                          ),
                        );
                      }
                    },
                  );
                } catch (e) {
                  print('Error loading quiz options: $e');
                  return Center(
                    child: Text(
                      'Error loading options: $e',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      );
    }
  }

  Widget _buildNavigationButtons(List<Question> questions) {
    final isLastQuestion = _currentQuestionIndex == questions.length - 1;
    final hasAnswer = _selectedOptions[questions[_currentQuestionIndex].id] !=
            null ||
        _textAnswers[questions[_currentQuestionIndex].id]?.isNotEmpty == true;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Previous Button
          if (_currentQuestionIndex > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousQuestion,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  side: const BorderSide(color: AppTheme.primaryBlue),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          if (_currentQuestionIndex > 0) const SizedBox(width: 16),

          // Next/Submit Button
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: hasAnswer
                  ? (isLastQuestion ? _submitQuiz : _nextQuestion)
                  : null,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(isLastQuestion ? Icons.send : Icons.arrow_forward),
              label: Text(
                _isSubmitting
                    ? 'Submitting...'
                    : (isLastQuestion ? 'Submit Quiz' : 'Next'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsScreen() {
    final score = _finalScore ?? 0;
    final isPassing = score >= 70;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isPassing ? AppTheme.successGreen : AppTheme.errorRed,
              (isPassing ? AppTheme.successGreen : AppTheme.errorRed)
                  .withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Result Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPassing ? Icons.check_circle : Icons.close,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Result Title
                    Text(
                      isPassing ? 'Congratulations!' : 'Keep Learning!',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Score Display
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${score.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Score',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(
                          'Correct',
                          '$_correctAnswers',
                          Icons.check_circle,
                          Colors.green,
                        ),
                        _buildStatItem(
                          'Total',
                          '$_totalQuestions',
                          Icons.quiz,
                          Colors.blue,
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back to Lesson'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showResults = false;
                                _currentQuestionIndex = 0;
                                _selectedOptions.clear();
                                _textAnswers.clear();
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retake Quiz'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: isPassing
                                  ? AppTheme.successGreen
                                  : AppTheme.errorRed,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizResult() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryBlue,
              AppTheme.primaryBlue.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Quiz Completed!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${_previousScore?.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'Your Score',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Lesson'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
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

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}
