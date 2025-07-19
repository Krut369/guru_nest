-- Fix lesson_progress table by adding the missing updated_at column
-- The trigger exists but the column doesn't, so we need to add it

-- Add updated_at column that the trigger expects
ALTER TABLE public.lesson_progress 
ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone DEFAULT timezone('utc', now());

-- The trigger should now work properly since the column exists
-- If you want to recreate the trigger to be sure:
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at_column') THEN
    DROP TRIGGER IF EXISTS update_lesson_progress_updated_at ON lesson_progress;
    CREATE TRIGGER update_lesson_progress_updated_at BEFORE
    UPDATE ON lesson_progress FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
  END IF;
END $$;

-- Update the mark_lesson_completed function to include updated_at
CREATE OR REPLACE FUNCTION mark_lesson_completed(student_uuid uuid, lesson_uuid uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO lesson_progress (student_id, lesson_id, is_completed)
  VALUES (student_uuid, lesson_uuid, true)
  ON CONFLICT (student_id, lesson_id) 
  DO UPDATE SET 
    completed_at = NOW(),
    is_completed = true,
    updated_at = NOW();
    
  -- Update user reports after marking lesson as completed
  PERFORM update_user_reports_on_lesson_completion(student_uuid);
END;
$$ LANGUAGE plpgsql;

-- Update the update_user_reports_on_lesson_completion function
CREATE OR REPLACE FUNCTION update_user_reports_on_lesson_completion(student_uuid uuid)
RETURNS void AS $$
BEGIN
  -- Update total_lessons_accessed count in user_reports
  UPDATE user_reports 
  SET 
    total_lessons_accessed = (
      SELECT COUNT(*) 
      FROM lesson_progress 
      WHERE student_id = student_uuid AND is_completed = true
    ),
    updated_at = NOW()
  WHERE user_id = student_uuid;
  
  -- Update learning streak
  PERFORM update_learning_streak_with_login(student_uuid);
END;
$$ LANGUAGE plpgsql; 