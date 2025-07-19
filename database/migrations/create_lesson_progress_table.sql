-- Create lesson_progress table to track student lesson completion
CREATE TABLE public.lesson_progress (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  student_id uuid NOT NULL,
  lesson_id uuid NOT NULL,
  completed_at timestamp with time zone DEFAULT timezone('utc', now()),
  is_completed boolean NOT NULL DEFAULT true,

  CONSTRAINT fk_student FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_lesson FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE,
  CONSTRAINT unique_student_lesson UNIQUE (student_id, lesson_id)
) TABLESPACE pg_default;

-- Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_lesson_progress_student_id ON public.lesson_progress (student_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_lesson_progress_lesson_id ON public.lesson_progress (lesson_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_lesson_progress_completed_at ON public.lesson_progress (completed_at) TABLESPACE pg_default;

-- Function to mark lesson as completed
CREATE OR REPLACE FUNCTION mark_lesson_completed(student_uuid uuid, lesson_uuid uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO lesson_progress (student_id, lesson_id, is_completed)
  VALUES (student_uuid, lesson_uuid, true)
  ON CONFLICT (student_id, lesson_id) 
  DO UPDATE SET 
    completed_at = NOW(),
    is_completed = true;
    
  -- Update user reports after marking lesson as completed
  PERFORM update_user_reports_on_lesson_completion(student_uuid);
END;
$$ LANGUAGE plpgsql;

-- Function to update user reports when lesson is completed
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
    )
  WHERE user_id = student_uuid;
  
  -- Update learning streak
  PERFORM update_learning_streak_with_login(student_uuid);
END;
$$ LANGUAGE plpgsql;

-- Function to get lesson completion status for a student
CREATE OR REPLACE FUNCTION get_lesson_completion_status(student_uuid uuid, lesson_uuid uuid)
RETURNS boolean AS $$
DECLARE
  is_completed boolean := false;
BEGIN
  SELECT lp.is_completed INTO is_completed
  FROM lesson_progress lp
  WHERE lp.student_id = student_uuid AND lp.lesson_id = lesson_uuid;
  
  RETURN COALESCE(is_completed, false);
END;
$$ LANGUAGE plpgsql;

-- Function to get all completed lessons for a student
CREATE OR REPLACE FUNCTION get_student_completed_lessons(student_uuid uuid)
RETURNS TABLE (
  lesson_id uuid,
  lesson_title text,
  completed_at timestamp with time zone,
  course_title text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    l.id as lesson_id,
    l.title as lesson_title,
    lp.completed_at,
    c.title as course_title
  FROM lesson_progress lp
  JOIN lessons l ON lp.lesson_id = l.id
  JOIN courses c ON l.course_id = c.id
  WHERE lp.student_id = student_uuid 
    AND lp.is_completed = true
  ORDER BY lp.completed_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get course completion percentage for a student
CREATE OR REPLACE FUNCTION get_course_completion_percentage(student_uuid uuid, course_uuid uuid)
RETURNS numeric AS $$
DECLARE
  total_lessons integer := 0;
  completed_lessons integer := 0;
  completion_percentage numeric := 0;
BEGIN
  -- Get total lessons in the course
  SELECT COUNT(*) INTO total_lessons
  FROM lessons
  WHERE course_id = course_uuid;
  
  -- Get completed lessons for this student in this course
  SELECT COUNT(*) INTO completed_lessons
  FROM lesson_progress lp
  JOIN lessons l ON lp.lesson_id = l.id
  WHERE lp.student_id = student_uuid 
    AND l.course_id = course_uuid 
    AND lp.is_completed = true;
  
  -- Calculate percentage
  IF total_lessons > 0 THEN
    completion_percentage := (completed_lessons::numeric / total_lessons::numeric) * 100;
  END IF;
  
  RETURN completion_percentage;
END;
$$ LANGUAGE plpgsql;

-- Function to get overall student progress
CREATE OR REPLACE FUNCTION get_student_overall_progress(student_uuid uuid)
RETURNS TABLE (
  total_courses integer,
  total_lessons integer,
  completed_lessons integer,
  overall_completion_percentage numeric
) AS $$
DECLARE
  total_courses_count integer := 0;
  total_lessons_count integer := 0;
  completed_lessons_count integer := 0;
  overall_percentage numeric := 0;
BEGIN
  -- Get total courses enrolled
  SELECT COUNT(DISTINCT course_id) INTO total_courses_count
  FROM enrollments
  WHERE student_id = student_uuid;
  
  -- Get total lessons across all enrolled courses
  SELECT COUNT(*) INTO total_lessons_count
  FROM lessons l
  JOIN enrollments e ON l.course_id = e.course_id
  WHERE e.student_id = student_uuid;
  
  -- Get completed lessons
  SELECT COUNT(*) INTO completed_lessons_count
  FROM lesson_progress
  WHERE student_id = student_uuid AND is_completed = true;
  
  -- Calculate overall percentage
  IF total_lessons_count > 0 THEN
    overall_percentage := (completed_lessons_count::numeric / total_lessons_count::numeric) * 100;
  END IF;
  
  RETURN QUERY SELECT 
    total_courses_count,
    total_lessons_count,
    completed_lessons_count,
    overall_percentage;
END;
$$ LANGUAGE plpgsql; 