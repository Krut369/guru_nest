import '../core/supabase_client.dart';

class FeedbackService {
  final _client = SupabaseService().instance;

  Future<List<Map<String, dynamic>>> fetchQuestions() async {
    final res = await _client
        .from('feedback_questions')
        .select('id, question_text')
        .eq('is_active', true)
        .order('created_at');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> submitFeedback({
    required String userId,
    required String lessonId,
    required List<Map<String, dynamic>> responses,
  }) async {
    // responses: [{question_id, rating, answer}]
    final payload = responses
        .map((r) => {
              'user_id': userId,
              'lesson_id': lessonId,
              'question_id': r['question_id'],
              'rating': r['rating'],
              'answer': r['answer'],
            })
        .toList();
    await _client.from('lesson_feedback_responses').insert(payload);
  }
}
