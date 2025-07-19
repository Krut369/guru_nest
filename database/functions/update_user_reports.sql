-- Function to update user reports when enrollments change
CREATE OR REPLACE FUNCTION update_user_reports_on_enrollment()
RETURNS TRIGGER AS $$
BEGIN
  -- Update total_courses_enrolled count
  UPDATE user_reports 
  SET 
    total_courses_enrolled = (
      SELECT COUNT(*) 
      FROM enrollments 
      WHERE student_id = COALESCE(NEW.student_id, OLD.student_id)
    ),
    updated_at = NOW()
  WHERE user_id = COALESCE(NEW.student_id, OLD.student_id);
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Function to update user reports when lesson access changes
CREATE OR REPLACE FUNCTION update_user_reports_on_lesson_access()
RETURNS TRIGGER AS $$
BEGIN
  -- Update total_lessons_accessed count
  UPDATE user_reports 
  SET 
    total_lessons_accessed = (
      SELECT COUNT(*) 
      FROM lesson_access 
      WHERE student_id = COALESCE(NEW.student_id, OLD.student_id)
    ),
    updated_at = NOW()
  WHERE user_id = COALESCE(NEW.student_id, OLD.student_id);
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Function to update user reports when material access changes
CREATE OR REPLACE FUNCTION update_user_reports_on_material_access()
RETURNS TRIGGER AS $$
BEGIN
  -- Update total_materials_accessed count
  UPDATE user_reports 
  SET 
    total_materials_accessed = (
      SELECT COUNT(*) 
      FROM material_access 
      WHERE student_id = COALESCE(NEW.student_id, OLD.student_id)
    ),
    updated_at = NOW()
  WHERE user_id = COALESCE(NEW.student_id, OLD.student_id);
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Function to update user reports when quiz results change
CREATE OR REPLACE FUNCTION update_user_reports_on_quiz_result()
RETURNS TRIGGER AS $$
BEGIN
  -- Update quiz-related metrics
  UPDATE user_reports 
  SET 
    total_quizzes = (
      SELECT COUNT(*) 
      FROM quiz_results 
      WHERE student_id = COALESCE(NEW.student_id, OLD.student_id)
    ),
    average_quiz_score = (
      SELECT COALESCE(AVG(score), 0) 
      FROM quiz_results 
      WHERE student_id = COALESCE(NEW.student_id, OLD.student_id)
    ),
    last_quiz_taken = (
      SELECT MAX(taken_at) 
      FROM quiz_results 
      WHERE student_id = COALESCE(NEW.student_id, OLD.student_id)
    ),
    updated_at = NOW()
  WHERE user_id = COALESCE(NEW.student_id, OLD.student_id);
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Function to calculate and update learning streak
CREATE OR REPLACE FUNCTION update_learning_streak(user_uuid uuid)
RETURNS void AS $$
DECLARE
  streak_count integer := 0;
  current_date date := CURRENT_DATE;
  activity_date date;
BEGIN
  -- Get all unique activity dates from lesson_access, material_access, and quiz_results
  WITH all_activities AS (
    SELECT DISTINCT DATE(accessed_at) as activity_date
    FROM lesson_access 
    WHERE student_id = user_uuid
    UNION
    SELECT DISTINCT DATE(accessed_at) as activity_date
    FROM material_access 
    WHERE student_id = user_uuid
    UNION
    SELECT DISTINCT DATE(taken_at) as activity_date
    FROM quiz_results 
    WHERE student_id = user_uuid
  ),
  sorted_activities AS (
    SELECT activity_date
    FROM all_activities
    ORDER BY activity_date DESC
  )
  SELECT activity_date INTO activity_date
  FROM sorted_activities
  LIMIT 1;
  
  -- Calculate consecutive days from today
  WHILE activity_date IS NOT NULL AND current_date >= activity_date LOOP
    IF current_date = activity_date THEN
      streak_count := streak_count + 1;
      current_date := current_date - INTERVAL '1 day';
      
      -- Get next activity date
      SELECT activity_date INTO activity_date
      FROM sorted_activities
      WHERE activity_date = current_date
      LIMIT 1;
    ELSE
      EXIT;
    END IF;
  END LOOP;
  
  -- Update learning streak in user_reports
  UPDATE user_reports 
  SET 
    learning_streak = streak_count,
    updated_at = NOW()
  WHERE user_id = user_uuid;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for automatic updates
DROP TRIGGER IF EXISTS trigger_update_user_reports_on_enrollment ON enrollments;
CREATE TRIGGER trigger_update_user_reports_on_enrollment
  AFTER INSERT OR UPDATE OR DELETE ON enrollments
  FOR EACH ROW
  EXECUTE FUNCTION update_user_reports_on_enrollment();

DROP TRIGGER IF EXISTS trigger_update_user_reports_on_lesson_access ON lesson_access;
CREATE TRIGGER trigger_update_user_reports_on_lesson_access
  AFTER INSERT OR UPDATE OR DELETE ON lesson_access
  FOR EACH ROW
  EXECUTE FUNCTION update_user_reports_on_lesson_access();

DROP TRIGGER IF EXISTS trigger_update_user_reports_on_material_access ON material_access;
CREATE TRIGGER trigger_update_user_reports_on_material_access
  AFTER INSERT OR UPDATE OR DELETE ON material_access
  FOR EACH ROW
  EXECUTE FUNCTION update_user_reports_on_material_access();

DROP TRIGGER IF EXISTS trigger_update_user_reports_on_quiz_result ON quiz_results;
CREATE TRIGGER trigger_update_user_reports_on_quiz_result
  AFTER INSERT OR UPDATE OR DELETE ON quiz_results
  FOR EACH ROW
  EXECUTE FUNCTION update_user_reports_on_quiz_result();

-- Function to initialize user reports for existing users
CREATE OR REPLACE FUNCTION initialize_user_reports()
RETURNS void AS $$
DECLARE
  user_record RECORD;
BEGIN
  FOR user_record IN SELECT id FROM users LOOP
    -- Insert user report if it doesn't exist
    INSERT INTO user_reports (
      user_id,
      total_courses_enrolled,
      total_lessons_accessed,
      total_materials_accessed,
      average_quiz_score,
      total_quizzes,
      learning_streak
    )
    SELECT 
      user_record.id,
      COALESCE(COUNT(DISTINCT e.id), 0),
      COALESCE(COUNT(DISTINCT la.lesson_id), 0),
      COALESCE(COUNT(DISTINCT ma.material_id), 0),
      COALESCE(AVG(qr.score), 0),
      COALESCE(COUNT(DISTINCT qr.id), 0),
      0
    FROM users u
    LEFT JOIN enrollments e ON u.id = e.student_id
    LEFT JOIN lesson_access la ON u.id = la.student_id
    LEFT JOIN material_access ma ON u.id = ma.student_id
    LEFT JOIN quiz_results qr ON u.id = qr.student_id
    WHERE u.id = user_record.id
    GROUP BY u.id
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Update learning streak for this user
    PERFORM update_learning_streak(user_record.id);
  END LOOP;
END;
$$ LANGUAGE plpgsql; 