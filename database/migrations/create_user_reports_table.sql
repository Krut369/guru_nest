-- Create user_reports table
CREATE TABLE public.user_reports (
  user_id uuid NOT NULL,
  total_courses_enrolled integer NULL DEFAULT 0,
  total_lessons_accessed integer NULL DEFAULT 0,
  total_materials_accessed integer NULL DEFAULT 0,
  average_quiz_score double precision NULL DEFAULT 0,
  last_quiz_taken timestamp with time zone NULL,
  total_quizzes integer NULL DEFAULT 0,
  learning_streak integer NULL DEFAULT 0,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT user_reports_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create index on user_id
CREATE INDEX IF NOT EXISTS idx_user_reports_user_id ON public.user_reports USING btree (user_id) TABLESPACE pg_default;

-- Create trigger to update updated_at column
CREATE TRIGGER update_user_reports_updated_at BEFORE
UPDATE ON user_reports FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Insert initial records for existing users (if any)
INSERT INTO public.user_reports (user_id, total_courses_enrolled, total_lessons_accessed, total_materials_accessed, average_quiz_score, total_quizzes, learning_streak)
SELECT 
  u.id,
  COALESCE(COUNT(DISTINCT e.id), 0) as total_courses_enrolled,
  COALESCE(COUNT(DISTINCT la.lesson_id), 0) as total_lessons_accessed,
  COALESCE(COUNT(DISTINCT ma.material_id), 0) as total_materials_accessed,
  COALESCE(AVG(qr.score), 0) as average_quiz_score,
  COALESCE(COUNT(DISTINCT qr.id), 0) as total_quizzes,
  0 as learning_streak
FROM users u
LEFT JOIN enrollments e ON u.id = e.user_id
LEFT JOIN lesson_access la ON u.id = la.user_id
LEFT JOIN material_access ma ON u.id = ma.user_id
LEFT JOIN quiz_results qr ON u.id = qr.user_id
GROUP BY u.id
ON CONFLICT (user_id) DO NOTHING; 