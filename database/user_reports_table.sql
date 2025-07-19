-- Create user_reports table for student analytics
CREATE TABLE public.user_reports (
  user_id uuid NOT NULL,
  total_courses_enrolled integer NULL DEFAULT 0,
  total_lessons_accessed integer NULL DEFAULT 0,
  total_materials_accessed integer NULL DEFAULT 0,
  average_quiz_score double precision NULL DEFAULT 0,
  last_quiz_taken timestamp with time zone NULL,
  total_quizzes integer NULL DEFAULT 0,
  learning_streak integer NULL DEFAULT 0,
  weekly_goals integer NULL DEFAULT 0,
  weekly_completed integer NULL DEFAULT 0,
  unread_messages integer NULL DEFAULT 0,
  CONSTRAINT user_reports_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create index for better performance
CREATE INDEX idx_user_reports_user_id ON public.user_reports(user_id);

-- Insert default records for existing users (optional)
-- This can be run after table creation to populate initial data
-- INSERT INTO public.user_reports (user_id, total_courses_enrolled, total_lessons_accessed, total_materials_accessed, average_quiz_score, total_quizzes, learning_streak, weekly_goals, weekly_completed, unread_messages)
-- SELECT id, 0, 0, 0, 0.0, 0, 0, 0, 0, 0 FROM public.users WHERE id NOT IN (SELECT user_id FROM public.user_reports);

-- Create RLS policies
ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;

-- Policy to allow users to read their own reports
CREATE POLICY "Users can view their own reports" ON public.user_reports
  FOR SELECT USING (auth.uid() = user_id);

-- Policy to allow users to update their own reports
CREATE POLICY "Users can update their own reports" ON public.user_reports
  FOR UPDATE USING (auth.uid() = user_id);

-- Policy to allow users to insert their own reports
CREATE POLICY "Users can insert their own reports" ON public.user_reports
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create functions for incrementing counters
CREATE OR REPLACE FUNCTION increment_courses_enrolled(user_id uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO public.user_reports (user_id, total_courses_enrolled)
  VALUES (user_id, 1)
  ON CONFLICT (user_id)
  DO UPDATE SET total_courses_enrolled = user_reports.total_courses_enrolled + 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION increment_lessons_accessed(user_id uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO public.user_reports (user_id, total_lessons_accessed)
  VALUES (user_id, 1)
  ON CONFLICT (user_id)
  DO UPDATE SET total_lessons_accessed = user_reports.total_lessons_accessed + 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION increment_materials_accessed(user_id uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO public.user_reports (user_id, total_materials_accessed)
  VALUES (user_id, 1)
  ON CONFLICT (user_id)
  DO UPDATE SET total_materials_accessed = user_reports.total_materials_accessed + 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 