import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../views/lesson_detail_page.dart';

class LessonCard extends StatelessWidget {
  final String lessonId;
  final String lessonTitle;
  final String? lessonDescription;
  final String courseId;
  final String courseTitle;
  final bool isCompleted;
  final int orderIndex;
  final VoidCallback? onTap;

  const LessonCard({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    this.lessonDescription,
    required this.courseId,
    required this.courseTitle,
    this.isCompleted = false,
    this.orderIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCompleted ? AppTheme.successGreen : Colors.grey[300]!,
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap ??
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LessonDetailPage(
                    lessonId: lessonId,
                    lessonTitle: lessonTitle,
                    lessonDescription: lessonDescription,
                    courseId: courseId,
                  ),
                ),
              );
            },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppTheme.successGreen
                          : AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isCompleted ? Icons.check : Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lessonTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isCompleted
                                ? AppTheme.successGreen
                                : Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          courseTitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCompleted)
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.successGreen,
                      size: 24,
                    ),
                ],
              ),
              if (lessonDescription != null &&
                  lessonDescription!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  lessonDescription!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppTheme.successGreen.withOpacity(0.1)
                          : AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isCompleted ? 'Completed' : 'Lesson ${orderIndex + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isCompleted
                            ? AppTheme.successGreen
                            : AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
