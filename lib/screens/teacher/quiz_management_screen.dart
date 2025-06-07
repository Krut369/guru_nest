import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import 'add_quiz_screen.dart';
import 'edit_quiz_screen.dart';
import 'quiz_questions_screen.dart';

class QuizManagementScreen extends StatefulWidget {
  final String courseId;

  const QuizManagementScreen({
    super.key,
    required this.courseId,
  });

  @override
  State<QuizManagementScreen> createState() => _QuizManagementScreenState();
}

class _QuizManagementScreenState extends State<QuizManagementScreen> {
  List<Map<String, dynamic>> _quizzes = [];
  List<Map<String, dynamic>> _courses = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedCourseId;
  final Map<String, dynamic> _quizStats = {};

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await Supabase.instance.client
          .from('courses')
          .select('id, title')
          .order('created_at', ascending: false);

      setState(() {
        _courses = List<Map<String, dynamic>>.from(courses);
        _isLoading = false;
      });

      if (_courses.isNotEmpty) {
        _selectedCourseId = _courses[0]['id'].toString();
        _loadQuizzes();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadQuizzes() async {
    if (_selectedCourseId == null) return;

    setState(() => _isLoading = true);

    try {
      final courseId = _selectedCourseId!;
      // First, get the quizzes
      final quizzes = await Supabase.instance.client
          .from('quizzes')
          .select('*')
          .eq('course_id', courseId)
          .order('id', ascending: false);

      setState(() {
        _quizzes = List<Map<String, dynamic>>.from(quizzes);
        _isLoading = false;
      });

      // Load quiz statistics and question counts
      for (var quiz in _quizzes) {
        // Get question count
        final questions = await Supabase.instance.client
            .from('quiz_questions')
            .select('id')
            .eq('quiz_id', quiz['id']);

        // Get attempt count
        final attempts = await Supabase.instance.client
            .from('quiz_results')
            .select('id')
            .eq('quiz_id', quiz['id']);

        // Get quiz stats
        final stats = await _loadQuizStats(quiz['id']);

        setState(() {
          _quizStats[quiz['id']] = {
            ...stats,
            'questionCount': questions.length,
            'attemptCount': attempts.length,
          };
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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

      final scores =
          results.map((r) => (r['score'] as num).toDouble()).toList();
      final averageScore = scores.reduce((a, b) => a + b) / scores.length;
      final highestScore = scores.reduce((a, b) => a > b ? a : b);

      return {
        'averageScore': averageScore,
        'totalAttempts': scores.length,
        'highestScore': highestScore,
      };
    } catch (e) {
      print('Error loading quiz stats: $e');
      return {
        'averageScore': 0.0,
        'totalAttempts': 0,
        'highestScore': 0.0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Management Screen'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
            'Error: $_error',
            style: const TextStyle(color: AppTheme.errorRed),
          ),
        ),
      );
    }

    if (_courses.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Management Screen'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Please create a course first'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Management'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              if (_selectedCourseId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a course first'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
                return;
              }

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddQuizScreen(
                    courseId: _selectedCourseId!,
                  ),
                ),
              );

              if (result != null) {
                _loadQuizzes();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedCourseId,
              decoration: InputDecoration(
                labelText: 'Select Course',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: _courses.map((course) {
                return DropdownMenuItem<String>(
                  value: course['id'].toString(),
                  child: Text(course['title'] ?? 'Untitled Course'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCourseId = value);
                  _loadQuizzes();
                }
              },
            ),
          ),
          Expanded(
            child: _quizzes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.quiz_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No quizzes found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (_selectedCourseId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a course first'),
                                  backgroundColor: AppTheme.errorRed,
                                ),
                              );
                              return;
                            }

                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddQuizScreen(
                                  courseId: _selectedCourseId!,
                                ),
                              ),
                            );

                            if (result != null) {
                              _loadQuizzes();
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Quiz'),
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
                    itemCount: _quizzes.length,
                    itemBuilder: (context, index) {
                      final quiz = _quizzes[index];
                      final stats = _quizStats[quiz['id']] ??
                          {
                            'averageScore': 0.0,
                            'totalAttempts': 0,
                            'highestScore': 0.0,
                          };

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                quiz['title'] ?? 'Untitled Quiz',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    quiz['description'] ?? 'No description',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      _buildStatItem(
                                        Icons.question_answer,
                                        '${_quizStats[quiz['id']]?['questionCount'] ?? 0} Questions',
                                      ),
                                      const SizedBox(width: 16),
                                      _buildStatItem(
                                        Icons.people,
                                        '${_quizStats[quiz['id']]?['attemptCount'] ?? 0} Attempts',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatCard(
                                    'Average Score',
                                    '${stats['averageScore'].toStringAsFixed(1)}%',
                                    Icons.bar_chart,
                                    AppTheme.primaryBlue,
                                  ),
                                  _buildStatCard(
                                    'Highest Score',
                                    '${stats['highestScore'].toStringAsFixed(1)}%',
                                    Icons.emoji_events,
                                    Colors.amber,
                                  ),
                                  _buildStatCard(
                                    'Total Attempts',
                                    stats['totalAttempts'].toString(),
                                    Icons.people,
                                    Colors.green,
                                  ),
                                ],
                              ),
                            ),
                            OverflowBar(
                              alignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.question_answer),
                                  label: const Text('Questions'),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            QuizQuestionsScreen(
                                          quizId: quiz['id'],
                                          quizTitle:
                                              quiz['title'] ?? 'Untitled Quiz',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit'),
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditQuizScreen(
                                          quizId: quiz['id'],
                                          courseId: _selectedCourseId!,
                                          quizData: quiz,
                                        ),
                                      ),
                                    );

                                    if (result == true) {
                                      _loadQuizzes();
                                    }
                                  },
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Delete'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.errorRed,
                                  ),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Quiz'),
                                        content: const Text(
                                            'Are you sure you want to delete this quiz? This action cannot be undone.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AppTheme.errorRed,
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed == true) {
                                      try {
                                        await Supabase.instance.client
                                            .from('quizzes')
                                            .delete()
                                            .eq('id', quiz['id']);
                                        _loadQuizzes();
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Error deleting quiz: $e'),
                                              backgroundColor:
                                                  AppTheme.errorRed,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
