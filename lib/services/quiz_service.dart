import 'dart:convert';

import 'package:http/http.dart' as http;

class QuizService {
  static const String _apiKey =
      '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';
  static const String _apiUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  Future<List<Map<String, dynamic>>> generateQuiz({
    required String topic,
    required int numberOfQuestions,
    required String difficulty,
  }) async {
    try {
      final prompt = '''
Generate a quiz about $topic with $numberOfQuestions questions of $difficulty difficulty.
Format the response as a JSON array of questions, each with:
- question: string
- options: array of 4 strings
- correctAnswer: number (0-3)
- explanation: string

Example format:
[
  {
    "question": "What is...?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctAnswer": 0,
    "explanation": "Explanation here"
  }
]
''';

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
          'max_tokens': 2000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

        // Parse the JSON string into a List of Maps
        final List<dynamic> quizData = jsonDecode(content);
        return quizData.cast<Map<String, dynamic>>();
      } else {
        print('Groq API error: ${response.statusCode}');
        print('Groq API response: ${response.body}');
        throw Exception('Failed to generate quiz: ${response.body}');
      }
    } catch (e) {
      print(e);
      throw Exception('Error generating quiz: $e');
    }
  }

  // Save quiz to datab q      ase
  Future<void> saveQuiz({
    required String courseId,
    required String title,
    required List<Map<String, dynamic>> questions,
  }) async {
    try {
      // First create the quiz
      final quizResponse = await http.post(
        Uri.parse('YOUR_SUPABASE_URL/rest/v1/quizzes'),
        headers: {
          'apikey': 'YOUR_SUPABASE_ANON_KEY',
          'Authorization': 'Bearer YOUR_SUPABASE_ANON_KEY',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode({
          'course_id': courseId,
          'title': title,
          'created_at': DateTime.now().toIso8601String(),
        }),
      );

      if (quizResponse.statusCode != 201) {
        throw Exception('Failed to create quiz: ${quizResponse.body}');
      }

      // Then create the questions
      for (var question in questions) {
        final questionResponse = await http.post(
          Uri.parse('YOUR_SUPABASE_URL/rest/v1/quiz_questions'),
          headers: {
            'apikey': 'YOUR_SUPABASE_ANON_KEY',
            'Authorization': 'Bearer YOUR_SUPABASE_ANON_KEY',
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          },
          body: jsonEncode({
            'quiz_id': quizResponse.body,
            'question': question['question'],
            'options': question['options'],
            'correct_answer': question['correctAnswer'],
            'explanation': question['explanation'],
          }),
        );

        if (questionResponse.statusCode != 201) {
          throw Exception(
              'Failed to create question: ${questionResponse.body}');
        }
      }
    } catch (e) {
      throw Exception('Error saving quiz: $e');
    }
  }
}
