-- Create triggers to automatically update user_reports when users perform actions
-- This ensures all count fields are always up-to-date

-- Trigger for course enrollments
CREATE OR REPLACE FUNCTION trigger_update_courses_enrolled()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Increment total_courses_enrolled when user enrolls in a course
    PERFORM increment_user_report_counter(NEW.student_id, 'total_courses_enrolled', 1);
  ELSIF TG_OP = 'DELETE' THEN
    -- Decrement total_courses_enrolled when user unenrolls from a course
    UPDATE user_reports 
    SET total_courses_enrolled = GREATEST(0, total_courses_enrolled - 1),
        updated_at = NOW()
    WHERE user_id = OLD.student_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER IF NOT EXISTS trigger_enrollments_update_reports
  AFTER INSERT OR DELETE ON enrollments
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_courses_enrolled();

-- Trigger for lesson access
CREATE OR REPLACE FUNCTION trigger_update_lessons_accessed()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Increment total_lessons_accessed when user accesses a lesson
    PERFORM increment_user_report_counter(NEW.student_id, 'total_lessons_accessed', 1);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER IF NOT EXISTS trigger_lesson_access_update_reports
  AFTER INSERT ON lesson_access
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_lessons_accessed();

-- Trigger for material access
CREATE OR REPLACE FUNCTION trigger_update_materials_accessed()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Increment total_materials_accessed when user accesses a material
    PERFORM increment_user_report_counter(NEW.student_id, 'total_materials_accessed', 1);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER IF NOT EXISTS trigger_material_access_update_reports
  AFTER INSERT ON material_access
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_materials_accessed();

-- Trigger for quiz results
CREATE OR REPLACE FUNCTION trigger_update_quiz_stats()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Update quiz statistics when user takes a quiz
    PERFORM update_user_quiz_score(NEW.student_id, NEW.score, NEW.taken_at);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER IF NOT EXISTS trigger_quiz_results_update_reports
  AFTER INSERT ON quiz_results
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_quiz_stats();

-- Trigger for messages (unread count)
CREATE OR REPLACE FUNCTION trigger_update_unread_messages()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Increment unread_messages when a new message is sent to user
    UPDATE user_reports 
    SET unread_messages = unread_messages + 1,
        updated_at = NOW()
    WHERE user_id = NEW.recipient_id;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Update unread_messages when message read status changes
    IF OLD.read = false AND NEW.read = true THEN
      -- Message was marked as read, decrement count
      UPDATE user_reports 
      SET unread_messages = GREATEST(0, unread_messages - 1),
          updated_at = NOW()
      WHERE user_id = NEW.recipient_id;
    ELSIF OLD.read = true AND NEW.read = false THEN
      -- Message was marked as unread, increment count
      UPDATE user_reports 
      SET unread_messages = unread_messages + 1,
          updated_at = NOW()
      WHERE user_id = NEW.recipient_id;
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER IF NOT EXISTS trigger_messages_update_reports
  AFTER INSERT OR UPDATE ON messages
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_unread_messages();

-- Function to recalculate all user reports (useful for data migration)
CREATE OR REPLACE FUNCTION recalculate_all_user_reports()
RETURNS VOID AS $$
DECLARE
  user_record RECORD;
BEGIN
  FOR user_record IN SELECT DISTINCT id FROM users LOOP
    -- Delete existing report for this user
    DELETE FROM user_reports WHERE user_id = user_record.id;
    
    -- Calculate and insert new report
    INSERT INTO user_reports (
      user_id,
      total_courses_enrolled,
      total_lessons_accessed,
      total_materials_accessed,
      average_quiz_score,
      last_quiz_taken,
      total_quizzes,
      learning_streak,
      unread_messages
    )
    SELECT 
      user_record.id,
      COALESCE(enrollment_count.count, 0),
      COALESCE(lesson_count.count, 0),
      COALESCE(material_count.count, 0),
      COALESCE(quiz_stats.avg_score, 0.0),
      quiz_stats.last_taken,
      COALESCE(quiz_stats.total_quizzes, 0),
      COALESCE(streak.streak, 0),
      COALESCE(unread.count, 0)
    FROM (SELECT 1) AS dummy
    LEFT JOIN (
      SELECT COUNT(*) as count 
      FROM enrollments 
      WHERE student_id = user_record.id
    ) AS enrollment_count ON true
    LEFT JOIN (
      SELECT COUNT(*) as count 
      FROM lesson_access 
      WHERE student_id = user_record.id
    ) AS lesson_count ON true
    LEFT JOIN (
      SELECT COUNT(*) as count 
      FROM material_access 
      WHERE student_id = user_record.id
    ) AS material_count ON true
    LEFT JOIN (
      SELECT 
        AVG(score) as avg_score,
        MAX(taken_at) as last_taken,
        COUNT(*) as total_quizzes
      FROM quiz_results 
      WHERE student_id = user_record.id
    ) AS quiz_stats ON true
    LEFT JOIN (
      SELECT COUNT(*) as count 
      FROM messages 
      WHERE recipient_id = user_record.id AND read = false
    ) AS unread ON true
    LEFT JOIN (
      SELECT 0 as streak  -- Placeholder for learning streak calculation
    ) AS streak ON true;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to update learning streak for a specific user
CREATE OR REPLACE FUNCTION update_learning_streak_for_user(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  streak_count INTEGER := 0;
  current_date DATE := CURRENT_DATE;
  check_date DATE;
  has_activity BOOLEAN;
BEGIN
  -- Check if user has any activity today or yesterday
  SELECT EXISTS(
    SELECT 1 FROM (
      SELECT accessed_at::date as activity_date FROM lesson_access WHERE student_id = p_user_id
      UNION
      SELECT accessed_at::date as activity_date FROM material_access WHERE student_id = p_user_id
      UNION
      SELECT taken_at::date as activity_date FROM quiz_results WHERE student_id = p_user_id
    ) activities
    WHERE activity_date IN (current_date, current_date - INTERVAL '1 day')
  ) INTO has_activity;
  
  IF NOT has_activity THEN
    RETURN 0;
  END IF;
  
  -- Calculate consecutive days
  streak_count := 1;
  check_date := current_date - INTERVAL '1 day';
  
  WHILE check_date >= current_date - INTERVAL '30 days' LOOP
    SELECT EXISTS(
      SELECT 1 FROM (
        SELECT accessed_at::date as activity_date FROM lesson_access WHERE student_id = p_user_id
        UNION
        SELECT accessed_at::date as activity_date FROM material_access WHERE student_id = p_user_id
        UNION
        SELECT taken_at::date as activity_date FROM quiz_results WHERE student_id = p_user_id
      ) activities
      WHERE activity_date = check_date
    ) INTO has_activity;
    
    IF has_activity THEN
      streak_count := streak_count + 1;
      check_date := check_date - INTERVAL '1 day';
    ELSE
      EXIT;
    END IF;
  END LOOP;
  
  -- Update the user report
  PERFORM update_user_learning_streak(p_user_id, streak_count);
  
  RETURN streak_count;
END;
$$ LANGUAGE plpgsql;

-- Function to update learning streaks for all users (run periodically)
CREATE OR REPLACE FUNCTION update_all_learning_streaks()
RETURNS VOID AS $$
DECLARE
  user_record RECORD;
BEGIN
  FOR user_record IN SELECT id FROM users LOOP
    PERFORM update_learning_streak_for_user(user_record.id);
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Add comments for documentation
COMMENT ON FUNCTION trigger_update_courses_enrolled() IS 'Trigger function to update total_courses_enrolled when users enroll/unenroll from courses';
COMMENT ON FUNCTION trigger_update_lessons_accessed() IS 'Trigger function to update total_lessons_accessed when users access lessons';
COMMENT ON FUNCTION trigger_update_materials_accessed() IS 'Trigger function to update total_materials_accessed when users access materials';
COMMENT ON FUNCTION trigger_update_quiz_stats() IS 'Trigger function to update quiz statistics when users take quizzes';
COMMENT ON FUNCTION trigger_update_unread_messages() IS 'Trigger function to update unread_messages count when messages are sent/read';
COMMENT ON FUNCTION recalculate_all_user_reports() IS 'Function to recalculate all user reports (useful for data migration)';
COMMENT ON FUNCTION update_learning_streak_for_user(UUID) IS 'Function to calculate and update learning streak for a specific user';
COMMENT ON FUNCTION update_all_learning_streaks() IS 'Function to update learning streaks for all users (run periodically)'; 