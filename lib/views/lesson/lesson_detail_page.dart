import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Import for navigation
import 'package:guru_nest/services/course_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/supabase_client.dart'; // Import SupabaseService
import '../../core/theme/app_theme.dart';
import '../../models/lesson_model.dart';
import '../../models/material_model.dart' as mat_model;
import '../../models/quiz_model.dart'; // Import Quiz model

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
  late Future<List<mat_model.Material>> _materialsFuture;
  late Future<Quiz?> _quizFuture; // Future to fetch the quiz

  final CourseService _courseService = CourseService();
  final String _supabaseUrl = SupabaseService.supabaseUrl; // Get Supabase URL

  @override
  void initState() {
    super.initState();
    _lessonFuture = _courseService.fetchLessonById(widget.lessonId);
    _materialsFuture = _courseService.fetchMaterialsForLesson(widget.lessonId);
    _quizFuture =
        _courseService.fetchQuizByCourseId(widget.courseId); // Fetch quiz
  }

  Future<void> _launchMaterial(String filePath) async {
    // Construct the full public URL using the correct bucket name 'materials'
    final String publicUrl =
        '$_supabaseUrl/storage/v1/object/public/materials/$filePath';
    final uri = Uri.parse(publicUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Handle error: could not launch URL
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open material: $publicUrl'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Detail'),
      ),
      body: FutureBuilder<Lesson?>(
        future: _lessonFuture,
        builder: (context, lessonSnapshot) {
          if (lessonSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (lessonSnapshot.hasError) {
            return Center(
                child: Text('Error loading lesson: ${lessonSnapshot.error}'));
          } else if (!lessonSnapshot.hasData || lessonSnapshot.data == null) {
            return const Center(child: Text('Lesson not found'));
          }

          final lesson = lessonSnapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(AppTheme.defaultPadding),
            children: [
              // Lesson Title
              Text(
                lesson.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.defaultSpacing),
              // Lesson Content
              if (lesson.content != null)
                Text(
                  lesson.content!,
                  style: const TextStyle(fontSize: 16),
                ),
              const SizedBox(height: AppTheme.defaultSpacing),
              // Quiz Section (Conditionally displayed)
              FutureBuilder<Quiz?>(
                future: _quizFuture,
                builder: (context, quizSnapshot) {
                  if (quizSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (quizSnapshot.hasError) {
                    return Center(
                        child:
                            Text('Error loading quiz: ${quizSnapshot.error}'));
                  } else if (quizSnapshot.hasData &&
                      quizSnapshot.data != null) {
                    final quiz = quizSnapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quiz',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppTheme.smallSpacing),
                        Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppTheme.primaryBlue,
                              child: Icon(Icons.quiz,
                                  color: AppTheme.backgroundWhite),
                            ),
                            title: Text(quiz.title),
                            subtitle: Text(quiz.description ??
                                'Take the quiz to test your knowledge!'),
                            trailing:
                                const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              // TODO: Navigate to Quiz Page
                              context.push(
                                  '/quiz/${quiz.id}'); // We will define this route later
                            },
                          ),
                        ),
                        const SizedBox(height: AppTheme.defaultSpacing),
                      ],
                    );
                  } else {
                    return const SizedBox.shrink(); // No quiz available
                  }
                },
              ),
              // Materials Section
              const Text(
                'Materials',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.smallSpacing),
              FutureBuilder<List<mat_model.Material>>(
                future: _materialsFuture,
                builder: (context, materialsSnapshot) {
                  if (materialsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (materialsSnapshot.hasError) {
                    return Text(
                        'Error loading materials: ${materialsSnapshot.error}');
                  } else if (!materialsSnapshot.hasData ||
                      materialsSnapshot.data!.isEmpty) {
                    return const Text('No materials available.');
                  } else {
                    final materials = materialsSnapshot.data!;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: materials.length,
                      itemBuilder: (context, index) {
                        final material = materials[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppTheme.primaryBlue.withOpacity(0.1),
                            child: Icon(
                              _getMaterialIcon(material.type),
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          title: Text(material.title),
                          subtitle: Text(material.type),
                          onTap: () {
                            _launchMaterial(
                                material.fileUrl); // Pass the file path
                          },
                        );
                      },
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _getMaterialIcon(String type) {
    switch (type) {
      case 'video':
        return Icons.play_circle_fill;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'exercise':
        return Icons.assignment;
      case 'document':
        return Icons.description;
      default:
        return Icons.attach_file;
    }
  }
}
