import 'dart:convert';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:go_router/go_router.dart';
import 'package:iconly/iconly.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/supabase_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lesson_model.dart';
import '../../models/material_model.dart' as mat_model;
import '../../models/quiz_model.dart';
import '../../screens/material/material_viewer_screen.dart';
import '../../services/course_service.dart';
import '../../services/feedback_service.dart';
import '../../services/lesson_progress_service.dart';

class LessonDetailPage extends StatefulWidget {
  final String courseId;
  final String lessonId;

  const LessonDetailPage({
    super.key,
    required this.courseId,
    required this.lessonId,
  });

  @override
  State<LessonDetailPage> createState() => _LessonDetailPageState();
}

class _LessonDetailPageState extends State<LessonDetailPage> {
  late Future<Lesson?> _lessonFuture;
  late Future<List<mat_model.LessonMaterial>> _materialsFuture;
  late Future<Quiz?> _quizFuture;
  late Future<Map<String, dynamic>> _lessonDataFuture;

  final CourseService _courseService = CourseService();
  final LessonProgressService _lessonProgressService = LessonProgressService();
  final String _supabaseUrl = SupabaseService.supabaseUrl;

  bool _isLoading = true;
  String? _error;
  String? _userId;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadLessonData();
  }

  Future<void> _loadLessonData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get current user
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        _userId = userData['id'] as String;

        // Check if lesson is already completed
        if (_userId != null) {
          _isCompleted = await _lessonProgressService.isLessonCompleted(
            _userId!,
            widget.lessonId,
          );
        }
      }

      // Load all lesson data
      _lessonFuture = _courseService.fetchLessonById(widget.lessonId);
      _materialsFuture =
          _courseService.fetchMaterialsForLesson(widget.lessonId);
      _quizFuture =
          _courseService.fetchQuizByLessonId(widget.lessonId); // CHANGED

      // Load combined lesson data
      _lessonDataFuture = _loadCombinedLessonData();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _loadCombinedLessonData() async {
    final lesson = await _courseService.fetchLessonById(widget.lessonId);
    final materials =
        await _courseService.fetchMaterialsForLesson(widget.lessonId);
    final quiz =
        await _courseService.fetchQuizByLessonId(widget.lessonId); // CHANGED

    return {
      'lesson': lesson,
      'materials': materials,
      'quiz': quiz,
    };
  }

  Future<void> _launchMaterial(
      String fileUrl, String type, String title) async {
    try {
      final uri = Uri.parse(fileUrl);

      if (type == 'pdf') {
        if (kIsWeb) {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not open PDF: $fileUrl'),
                  backgroundColor: AppTheme.errorRed,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MaterialViewerScreen(
                  url: fileUrl,
                  type: type,
                  title: title,
                ),
              ),
            );
          }
        }
      } else if (type == 'video') {
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MaterialViewerScreen(
                url: fileUrl,
                type: type,
                title: title,
              ),
            ),
          );
        }
      } else {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open material: $fileUrl'),
                backgroundColor: AppTheme.errorRed,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening material: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _showFeedbackDialog() async {
    final feedbackService = FeedbackService();
    final questions = await feedbackService.fetchQuestions();
    final responses = List.generate(
        questions.length,
        (i) => {
              'question_id': questions[i]['id'],
              'rating': 0,
              'answer': '',
            });

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Lesson Feedback'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: questions.length,
                  itemBuilder: (context, i) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(questions[i]['question_text']),
                        Row(
                          children: List.generate(5, (star) {
                            return IconButton(
                              icon: Icon(
                                responses[i]['rating'] > star
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                              ),
                              onPressed: () {
                                setState(() {
                                  responses[i]['rating'] = star + 1;
                                });
                              },
                            );
                          }),
                        ),
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'Optional comment',
                          ),
                          onChanged: (val) {
                            responses[i]['answer'] = val;
                          },
                        ),
                        const Divider(),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    if (responses.any((r) => r['rating'] == 0)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please rate all questions!')),
                      );
                      return;
                    }
                    await feedbackService.submitFeedback(
                      userId: _userId!,
                      lessonId: widget.lessonId,
                      responses: responses,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Thank you for your feedback!')),
                    );
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _markAsCompleted() async {
    if (_userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to mark lesson as completed'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Show loading message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marking lesson as completed...'),
            backgroundColor: AppTheme.primaryBlue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Use LessonProgressService to mark lesson as completed
      await _lessonProgressService.markLessonCompleted(
        _userId!,
        widget.lessonId,
      );

      // Update local state
      setState(() {
        _isCompleted = true;
        _isLoading = false;
      });

      // Show feedback dialog after marking as completed
      await _showFeedbackDialog();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Lesson marked as completed! 🎉'),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Verify the completion was actually saved
      final verificationCompleted =
          await _lessonProgressService.isLessonCompleted(
        _userId!,
        widget.lessonId,
      );

      if (!verificationCompleted) {
        print('Warning: Lesson completion verification failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Warning: Lesson completion may not have been saved properly'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error marking lesson as completed: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Error:  e.toString()}'),
                ),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading lesson...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Lesson'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
        ),
        body: Center(
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
                'Error loading lesson',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.errorRed,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadLessonData,
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
      );
    }

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _lessonDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error loading lesson: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Lesson not found'));
          }

          final lessonData = snapshot.data!;
          final lesson = lessonData['lesson'] as Lesson;
          final materials =
              lessonData['materials'] as List<mat_model.LessonMaterial>;
          final quiz = lessonData['quiz'] as Quiz?;

          return CustomScrollView(
            slivers: [
              // App Bar with Lesson Info
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
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
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Lesson ${lesson.lessonOrder}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (_isCompleted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successGreen,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Completed',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            lesson.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 3,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  // Debug button for troubleshooting
                  IconButton(
                    icon: const Icon(Icons.bug_report),
                    onPressed: () async {
                      print('=== DEBUG BUTTON PRESSED ===');
                      await _lessonProgressService.debugCheckTableStructure();
                      if (_userId != null) {
                        await _lessonProgressService.debugCheckLessonProgress(
                          _userId!,
                          widget.lessonId,
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Share feature coming soon!'),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // Lesson Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lesson Content Section
                      if (lesson.content != null &&
                          lesson.content!.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Lesson Content',
                          IconlyBold.document,
                          AppTheme.primaryBlue,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey[200]!,
                            ),
                          ),
                          child: Text(
                            lesson.content!,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Materials Section
                      _buildSectionHeader(
                        'Learning Materials',
                        IconlyBold.folder,
                        Colors.green,
                      ),
                      const SizedBox(height: 16),
                      if (materials.isEmpty)
                        _buildEmptyState(
                          'No materials available',
                          'Materials will be added soon',
                          IconlyBold.folder,
                          Colors.grey[400]!,
                        )
                      else
                        _buildMaterialsList(materials),

                      const SizedBox(height: 32),

                      // Quiz Section
                      if (quiz != null) ...[
                        _buildSectionHeader(
                          'Quiz',
                          IconlyBold.tick_square,
                          Colors.orange,
                        ),
                        const SizedBox(height: 16),
                        _buildQuizCard(quiz),
                        const SizedBox(height: 32),
                      ],

                      // Completion Button
                      if (!_isCompleted)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _markAsCompleted,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text(
                              'Mark as Completed ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
      String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: color,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsList(List<mat_model.LessonMaterial> materials) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: materials.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final material = materials[index];
        String type = material.type.toLowerCase().trim();
        final url = material.fileUrl.toLowerCase();
        // Detect video by file extension if type is not set correctly
        if (type != 'video' &&
            (url.endsWith('.mp4') ||
                url.endsWith('.mkv') ||
                url.endsWith('.mov') ||
                url.endsWith('.webm'))) {
          type = 'video';
        }
        Icon leadingIcon;
        String viewType;
        if (type == 'video') {
          leadingIcon =
              const Icon(Icons.play_circle_fill, color: Colors.red, size: 32);
          viewType = 'Video';
        } else if (type == 'pdf') {
          leadingIcon =
              const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32);
          viewType = 'PDF';
        } else if (type == 'exercise') {
          leadingIcon = const Icon(Icons.edit, color: Colors.orange, size: 32);
          viewType = 'Exercise';
        } else if (type == 'document') {
          leadingIcon =
              const Icon(Icons.description, color: Colors.blue, size: 32);
          viewType = 'Document';
        } else {
          leadingIcon =
              const Icon(Icons.insert_drive_file, color: Colors.grey, size: 32);
          viewType = 'Other';
        }

        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: leadingIcon,
            title: Text(
              material.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Text(
              viewType,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            trailing: const Icon(Icons.remove_red_eye_outlined,
                color: AppTheme.primaryBlue),
            onTap: () {
              print('Opening material: type=$type, url=${material.fileUrl}');
              if (type == 'video' || type == 'pdf') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MaterialViewerScreen(
                      url: material.fileUrl,
                      type: type,
                      title: material.title,
                    ),
                  ),
                );
              } else {
                _launchMaterial(material.fileUrl, type, material.title);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildQuizCard(Quiz quiz) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.withOpacity(0.1),
            Colors.orange.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            IconlyBold.tick_square,
            color: Colors.orange,
            size: 24,
          ),
        ),
        title: Text(
          quiz.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              quiz.description ?? 'Test your knowledge with this quiz!',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Quiz',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.arrow_forward_ios,
            color: Colors.orange,
            size: 16,
          ),
        ),
        onTap: () {
          context.push('/quiz/${quiz.id}');
        },
      ),
    );
  }

  Color _getMaterialColor(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return Colors.red;
      case 'pdf':
        return Colors.red[700]!;
      case 'document':
        return Colors.blue;
      case 'image':
        return Colors.green;
      case 'audio':
        return Colors.purple;
      case 'exercise':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getMaterialIcon(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return IconlyBold.video;
      case 'pdf':
        return IconlyBold.document;
      case 'document':
        return IconlyBold.document;
      case 'image':
        return IconlyBold.image;
      case 'audio':
        return IconlyBold.volume_up;
      case 'exercise':
        return IconlyBold.edit;
      default:
        return IconlyBold.folder;
    }
  }

  String _getMaterialTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return 'Video Lesson';
      case 'pdf':
        return 'PDF Document';
      case 'document':
        return 'Document';
      case 'image':
        return 'Image';
      case 'audio':
        return 'Audio File';
      case 'exercise':
        return 'Exercise';
      default:
        return 'File';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  final String url;
  const _InlineVideoPlayer({required this.url});
  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  late VideoPlayerController _controller;
  ChewieController? _chewieController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
          _chewieController = ChewieController(
            videoPlayerController: _controller,
            autoPlay: false,
            looping: false,
          );
        });
      });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _chewieController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Chewie(controller: _chewieController!);
  }
}

class _InlinePdfViewer extends StatelessWidget {
  final String url;
  const _InlinePdfViewer({required this.url});
  @override
  Widget build(BuildContext context) {
    // For simplicity, just open the PDF in an external viewer for web
    if (kIsWeb) {
      return Center(
        child: ElevatedButton(
          onPressed: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: const Text('Open PDF'),
        ),
      );
    }
    // For mobile, use flutter_pdfview
    return PDFView(
      filePath: url,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      fitPolicy: FitPolicy.BOTH,
      preventLinkNavigation: false,
      onError: (error) {
        print('PDF viewer error: $error');
      },
      onPageError: (page, error) {
        print('PDF page error: $error');
      },
    );
  }
}
