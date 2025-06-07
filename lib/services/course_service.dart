import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/course_include_model.dart';
import '../models/course_learning_model.dart';
import '../models/course_model.dart';
import '../models/lesson_model.dart';
import '../models/material_model.dart';
import '../models/question_model.dart';
import '../models/quiz_model.dart';
import '../models/quiz_option_model.dart';
import '../services/user_reports_service.dart';

class CourseService {
  final _supabase = Supabase.instance.client;
  final _storage = Supabase.instance.client.storage;
  final _uuid = const Uuid();

  // Fetch all courses
  Future<List<Course>> fetchAllCourses() async {
    try {
      final response = await _supabase.from('courses').select('''
        *,
        teacher:users!teacher_id (
          id,
          full_name,
          email,
          avatar_url,
          role,
          created_at
        ),
        enrollments!course_id (count),
        rating
      ''').order('created_at', ascending: false);

      return (response as List).map((json) => Course.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching courses: $e');
      rethrow;
    }
  }

  // Fetch a single course by ID
  Future<Course> fetchCourseById(String courseId) async {
    try {
      final response = await _supabase.from('courses').select('''
            *,
            teacher:users!teacher_id (
              id,
              full_name,
              email,
              avatar_url,
              role,
              created_at
            ),
            enrollments!course_id (count),
            rating,
            lessons (
              *,
              materials (
                *
              )
            )
          ''').eq('id', courseId).single();

      // Log the response for debugging
      print('Course response: $response');
      print('Teacher data in response: ${response['teacher']}');
      print('Teacher ID: ${response['teacher_id']}');

      // Check each required field and collect missing ones
      final missingFields = <String>[];
      if (response['id'] == null) missingFields.add('id');
      if (response['title'] == null) missingFields.add('title');
      if (response['description'] == null) missingFields.add('description');
      if (response['price'] == null) missingFields.add('price');
      if (response['created_at'] == null) missingFields.add('created_at');

      if (missingFields.isNotEmpty) {
        throw Exception(
            'Course data is missing required fields: ${missingFields.join(', ')}');
      }

      return Course.fromJson(response);
    } catch (e) {
      print('Error fetching course by ID: $e');
      rethrow;
    }
  }

  // Fetch lessons for a course
  Future<List<Lesson>> fetchLessonsForCourse(String courseId) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select()
          .eq('course_id', courseId)
          .order('lesson_order');

      return response.map((json) => Lesson.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching lessons: $e');
      rethrow;
    }
  }

  // Get lesson count for a course
  Future<int> getLessonCount(String courseId) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('id')
          .eq('course_id', courseId)
          .count();

      return response.count ?? 0;
    } catch (e) {
      print('Error fetching lesson count: $e');
      return 0;
    }
  }

  // Fetch a single lesson by ID
  Future<Lesson> fetchLessonById(String lessonId) async {
    try {
      final response = await _supabase.from('lessons').select('''
            *,
            materials (
              *
            )
          ''').eq('id', lessonId).single();

      return Lesson.fromJson(response);
    } catch (e) {
      print('Error fetching lesson by ID: $e');
      rethrow;
    }
  }

  // Fetch materials for a lesson
  Future<List<LessonMaterial>> fetchMaterialsForLesson(String lessonId) async {
    try {
      final response = await _supabase
          .from('materials')
          .select()
          .eq('lesson_id', lessonId)
          .order('uploaded_at'); // Assuming order by upload time

      // Note: 'Material' might conflict with Flutter's Material. Consider renaming model.
      return response.map((json) => LessonMaterial.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching materials: $e');
      rethrow;
    }
  }

  Future<Quiz?> fetchQuizByCourseId(String courseId) async {
    try {
      final response = await _supabase
          .from('quizzes')
          .select('*')
          .eq('course_id', courseId)
          .single();

      return Quiz.fromJson(response);
    } catch (e) {
      // Handle case where no quiz is found gracefully
      if (e is PostgrestException && e.code == 'PGRST116') {
        print('No quiz found for course ID $courseId');
        return null; // No quiz found for this course
      } else {
        print('Error fetching quiz by course ID: $e');
        rethrow;
      }
    }
  }

  Future<Quiz?> fetchQuizByLessonId(String lessonId) async {
    try {
      final response = await _supabase
          .from('quizzes')
          .select('*')
          .eq('lesson_id', lessonId)
          .single();
      return Quiz.fromJson(response);
    } catch (e) {
      // Handle case where no quiz is found gracefully
      if (e is PostgrestException && e.code == 'PGRST116') {
        print('No quiz found for lesson ID $lessonId');
        return null; // No quiz found for this lesson
      } else {
        print('Error fetching quiz by lesson ID: $e');
        rethrow;
      }
    }
  }

  Future<List<Question>> fetchQuestionsByQuizId(String quizId) async {
    try {
      final response = await _supabase
          .from('quiz_questions')
          .select('*')
          .eq('quiz_id', quizId)
          .order('id', ascending: true); // Changed from 'order' to 'id'

      return (response as List).map((json) => Question.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching questions by quiz ID: $e');
      rethrow;
    }
  }

  Future<List<QuizOption>> fetchQuizOptionsByQuestionId(
      String questionId) async {
    try {
      final response = await _supabase
          .from('quiz_options')
          .select('*')
          .eq('question_id', questionId)
          .order('id', ascending: true); // Or another relevant order

      return (response as List)
          .map((json) => QuizOption.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching quiz options by question ID: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchQuizWithQuestionsAndOptions(
      String quizId) async {
    try {
      // First fetch the quiz
      final quizResponse =
          await _supabase.from('quizzes').select('*').eq('id', quizId).single();

      print('Quiz response: $quizResponse');

      // Then fetch questions for this quiz
      final questionsResponse = await _supabase
          .from('quiz_questions')
          .select('*')
          .eq('quiz_id', quizId)
          .order('id', ascending: true);

      print('Questions response: $questionsResponse');

      // For each question, fetch its options
      final questionsWithOptions = await Future.wait(
        (questionsResponse as List).map((question) async {
          final optionsResponse = await _supabase
              .from('quiz_options')
              .select('*')
              .eq('question_id', question['id'])
              .order('id', ascending: true);

          print('Options for question ${question['id']}: $optionsResponse');

          return {
            ...Map<String, dynamic>.from(question),
            'quiz_options': optionsResponse,
          };
        }),
      );

      final result = {
        'quiz': quizResponse,
        'quiz_questions': questionsWithOptions,
      };

      print('Final result structure: ${result.keys}');
      print('Number of questions: ${questionsWithOptions.length}');

      return result;
    } catch (e) {
      print('Error fetching quiz with questions and options: $e');
      rethrow;
    }
  }

  // TODO: Add functions for creating courses, enrollments, lessons, materials, etc.

  Future<bool> hasStudentTakenQuiz(String quizId, String studentId) async {
    try {
      final response = await _supabase
          .from('quiz_results')
          .select()
          .eq('quiz_id', quizId)
          .eq('student_id', studentId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking if student has taken quiz: $e');
      rethrow;
    }
  }

  Future<void> saveQuizResult({
    required String quizId,
    required String studentId,
    required double score,
  }) async {
    try {
      // Check if student has already taken this quiz
      final hasTaken = await hasStudentTakenQuiz(quizId, studentId);
      if (hasTaken) {
        throw Exception(
            'You have already taken this quiz. Only one attempt is allowed.');
      }

      // Save quiz result
      await _supabase.from('quiz_results').insert({
        'quiz_id': quizId,
        'student_id': studentId,
        'score': score,
        'taken_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Update user report with new quiz score
      final userReportsService = UserReportsService();
      await userReportsService.updateQuizScore(studentId, score);

      print('Quiz result saved successfully');
    } catch (e) {
      print('Error saving quiz result: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getStudentQuizResults(
      String studentId) async {
    try {
      final response = await _supabase.from('quiz_results').select('''
            *,
            quizzes!quiz_id (
              id,
              title,
              course_id,
              courses!course_id (
                id,
                title
              )
            )
          ''').eq('student_id', studentId).order('taken_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching student quiz results: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getQuizStatistics(String quizId) async {
    try {
      final response = await _supabase
          .from('quiz_results')
          .select('score')
          .eq('quiz_id', quizId);

      if (response.isEmpty) {
        return {
          'average_score': 0.0,
          'total_attempts': 0,
          'highest_score': 0.0,
          'lowest_score': 0.0,
        };
      }

      final scores =
          (response as List).map((r) => r['score'] as double).toList();
      final averageScore = scores.reduce((a, b) => a + b) / scores.length;
      final highestScore = scores.reduce((a, b) => a > b ? a : b);
      final lowestScore = scores.reduce((a, b) => a < b ? a : b);

      return {
        'average_score': averageScore,
        'total_attempts': scores.length,
        'highest_score': highestScore,
        'lowest_score': lowestScore,
      };
    } catch (e) {
      print('Error fetching quiz statistics: $e');
      rethrow;
    }
  }

  Future<void> enrollInCourse({
    required String courseId,
    required String studentId,
  }) async {
    try {
      await _supabase.from('enrollments').insert({
        'course_id': courseId,
        'student_id': studentId,
        'enrolled_at': DateTime.now().toIso8601String(),
      });

      // Update user report with new course enrollment
      final userReportsService = UserReportsService();
      await userReportsService.incrementCoursesEnrolled(studentId);

      print('Enrolled in course successfully');
    } catch (e) {
      print('Error enrolling in course: $e');
      rethrow;
    }
  }

  Future<void> markLessonAsAccessed({
    required String lessonId,
    required String studentId,
  }) async {
    try {
      await _supabase.from('lesson_access').insert({
        'lesson_id': lessonId,
        'student_id': studentId,
        'accessed_at': DateTime.now().toIso8601String(),
      });

      // Update user report with new lesson access
      final userReportsService = UserReportsService();
      await userReportsService.incrementLessonsAccessed(studentId);

      print('Lesson marked as accessed successfully');
    } catch (e) {
      print('Error marking lesson as accessed: $e');
      rethrow;
    }
  }

  Future<void> markMaterialAsAccessed({
    required String materialId,
    required String studentId,
  }) async {
    try {
      await _supabase.from('material_access').insert({
        'material_id': materialId,
        'student_id': studentId,
        'accessed_at': DateTime.now().toIso8601String(),
      });

      // Update user report with new material access
      final userReportsService = UserReportsService();
      await userReportsService.incrementMaterialsAccessed(studentId);

      print('Material marked as accessed successfully');
    } catch (e) {
      print('Error marking material as accessed: $e');
      rethrow;
    }
  }

  Future<Course> getCourse(String courseId) async {
    try {
      final response =
          await _supabase.from('courses').select().eq('id', courseId).single();

      return Course.fromJson(response);
    } catch (e) {
      print('Error fetching course: $e');
      rethrow;
    }
  }

  Future<List<Course>> getCourses() async {
    try {
      final response = await _supabase
          .from('courses')
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((json) => Course.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching courses: $e');
      rethrow;
    }
  }

  Future<List<Course>> getInstructorCourses(String instructorId) async {
    try {
      final response = await _supabase
          .from('courses')
          .select()
          .eq('instructor_id', instructorId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Course.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching instructor courses: $e');
      rethrow;
    }
  }

  Future<Course> createCourse({
    required String title,
    required String description,
    required double price,
    required String categoryId,
    required Uint8List? imageBytes,
    required String teacherId,
    bool isPremium = false,
  }) async {
    String? imageUrl;
    try {
      print('Creating course with data:');
      print('Title: $title');
      print('Description: $description');
      print('Price: $price');
      print('Category ID: $categoryId');
      print('Teacher ID: $teacherId');
      print('Is Premium: $isPremium');

      // Upload image if provided
      if (imageBytes != null) {
        try {
          final fileName = '${_uuid.v4()}.jpg';
          print('Attempting to upload file: $fileName');

          // Upload to Supabase Storage using uploadBinary
          await _storage.from('courses').uploadBinary(
                fileName,
                imageBytes,
                fileOptions: const FileOptions(
                  cacheControl: '3600',
                  upsert: false,
                ),
              );

          print('File uploaded successfully');

          // Get public URL
          imageUrl = _storage.from('courses').getPublicUrl(fileName);
          print('Generated public URL: $imageUrl');
        } catch (e) {
          print('Error uploading file: $e');
          rethrow;
        }
      }

      // Create course record
      final courseData = {
        'title': title,
        'description': description,
        'price': price,
        'category_id': categoryId,
        'teacher_id': teacherId,
        'is_premium': isPremium,
        'image_url': imageUrl,
      };
      print('Inserting course data: $courseData');

      final response =
          await _supabase.from('courses').insert(courseData).select().single();

      print('Course created successfully: $response');
      return Course.fromJson(response);
    } catch (e) {
      print('Error in createCourse: $e');
      // If course creation fails, delete uploaded image
      if (imageUrl != null) {
        try {
          final fileName = imageUrl.split('/').last;
          await _storage.from('courses').remove([fileName]);
        } catch (e) {
          print('Error cleaning up image: $e');
        }
      }
      rethrow;
    }
  }

  Future<List<Course>> getTeacherCourses(String teacherId) async {
    try {
      final response = await _supabase
          .from('courses')
          .select('''
            *,
            teacher:users!teacher_id (
              id,
              full_name,
              email,
              avatar_url,
              role,
              created_at
            ),
            enrollments!course_id (count),
            rating,
            category:categories (
              id,
              name
            )
          ''')
          .eq('teacher_id', teacherId)
          .order('created_at', ascending: false);

      print('Teacher courses response: $response'); // Debug log

      return (response as List).map((json) => Course.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching teacher courses: $e'); // Debug log
      rethrow;
    }
  }

  Future<Course> getCourseDetails(String courseId) async {
    try {
      final response = await _supabase
          .from('courses')
          .select('*, teacher:users(*), category:categories(*)')
          .eq('id', courseId)
          .single();

      return Course.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<Course> updateCourse({
    required String courseId,
    String? title,
    String? description,
    double? price,
    String? categoryId,
    File? imageFile,
    bool? isPremium,
  }) async {
    try {
      String? imageUrl;

      // Upload new image if provided
      if (imageFile != null) {
        final fileExt = path.extension(imageFile.path);
        final fileName = '${_uuid.v4()}$fileExt';
        final filePath = 'courses/$fileName';

        // Upload to Supabase Storage
        await _storage.from('courses').upload(
              filePath,
              imageFile,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );

        // Get public URL
        imageUrl = _storage.from('courses').getPublicUrl(filePath);
      }

      // Update course record
      final response = await _supabase
          .from('courses')
          .update({
            if (title != null) 'title': title,
            if (description != null) 'description': description,
            if (price != null) 'price': price,
            if (categoryId != null) 'category_id': categoryId,
            if (isPremium != null) 'is_premium': isPremium,
            if (imageUrl != null) 'image_url': imageUrl,
          })
          .eq('id', courseId)
          .select()
          .single();

      return Course.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCourse(String courseId) async {
    try {
      // Get course details to delete associated image
      final course = await getCourseDetails(courseId);

      // Delete image from storage if exists
      if (course.imageUrl != null) {
        final filePath = course.imageUrl!.split('/').last;
        await _storage.from('courses').remove(['courses/$filePath']);
      }

      // Delete course record
      await _supabase.from('courses').delete().eq('id', courseId);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> uploadCourseMaterial({
    required File file,
    required String courseId,
    required String fileType,
    required String lessonId,
    void Function(double)? onProgress,
  }) async {
    try {
      final fileExt = file.path.split('.').last;
      final filePath =
          'materials/$courseId/$lessonId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // Upload file to Supabase Storage
      await _supabase.storage.from('materials').upload(
            filePath,
            file,
            fileOptions: FileOptions(
              contentType: fileType == 'pdf' ? 'application/pdf' : null,
            ),
          );

      // Get the public URL
      return _supabase.storage.from('materials').getPublicUrl(filePath);
    } catch (e) {
      print('Error uploading file: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCourseMaterials(String courseId) async {
    try {
      final response = await _supabase
          .from('storage_files')
          .select()
          .eq('course_id', courseId)
          .order('uploaded_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> uploadCourseMaterialWeb({
    required Uint8List bytes,
    required String fileName,
    required String courseId,
    required String fileType,
    required String lessonId,
    void Function(double)? onProgress,
  }) async {
    try {
      final fileExt = fileName.split('.').last;
      final filePath =
          'materials/$courseId/$lessonId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // Upload file to Supabase Storage
      await _supabase.storage.from('materials').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: fileType == 'pdf' ? 'application/pdf' : null,
            ),
          );

      // Get the public URL
      return _supabase.storage.from('materials').getPublicUrl(filePath);
    } catch (e) {
      print('Error uploading file: $e');
      rethrow;
    }
  }

  // Create a new lesson
  Future<void> createLesson({
    required String courseId,
    required String title,
    required String content,
    required int lessonOrder,
    String? lessonId,
  }) async {
    try {
      final id = lessonId ?? _uuid.v4();
      final lessonData = {
        'id': id,
        'course_id': courseId,
        'title': title,
        'content': content,
        'lesson_order': lessonOrder,
      };
      await _supabase.from('lessons').insert(lessonData);
    } catch (e) {
      print('Error creating lesson: $e');
      rethrow;
    }
  }

  // Update an existing lesson
  Future<void> updateLesson({
    required String lessonId,
    required String courseId,
    required String title,
    required String content,
    required int lessonOrder,
  }) async {
    try {
      final lessonData = {
        'course_id': courseId,
        'title': title,
        'content': content,
        'lesson_order': lessonOrder,
      };
      await _supabase.from('lessons').update(lessonData).eq('id', lessonId);
    } catch (e) {
      print('Error updating lesson: $e');
      rethrow;
    }
  }

  // Delete a lesson
  Future<void> deleteLesson(String lessonId) async {
    try {
      await _supabase.from('lessons').delete().eq('id', lessonId);
    } catch (e) {
      print('Error deleting lesson: $e');
      rethrow;
    }
  }

  // Fetch course includes
  Future<List<CourseInclude>> fetchCourseIncludes(String courseId) async {
    try {
      final response = await _supabase
          .from('course_includes')
          .select()
          .eq('course_id', courseId)
          .order('id');

      return response.map((json) => CourseInclude.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching course includes: $e');
      return [];
    }
  }

  // Fetch course learnings
  Future<List<CourseLearning>> fetchCourseLearnings(String courseId) async {
    try {
      final response = await _supabase
          .from('course_learnings')
          .select()
          .eq('course_id', courseId)
          .order('id');

      return response.map((json) => CourseLearning.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching course learnings: $e');
      return [];
    }
  }
}
