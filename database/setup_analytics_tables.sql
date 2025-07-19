-- Setup script for Analytics System
-- Run this script in your Supabase SQL editor to create all required tables

-- 1. Create user_reports table (if not exists)
CREATE TABLE IF NOT EXISTS public.user_reports (
  user_id uuid NOT NULL,
  total_courses_enrolled integer NULL DEFAULT 0,
  total_lessons_accessed integer NULL DEFAULT 0,
  total_materials_accessed integer NULL DEFAULT 0,
  average_quiz_score double precision NULL DEFAULT 0,
  last_quiz_taken timestamp with time zone NULL,
  total_quizzes integer NULL DEFAULT 0,
  CONSTRAINT user_reports_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- 2. Create lesson_access table (if not exists)
CREATE TABLE IF NOT EXISTS public.lesson_access (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  lesson_id uuid NOT NULL,
  student_id uuid NOT NULL,
  accessed_at timestamp with time zone DEFAULT now(),
  CONSTRAINT lesson_access_lesson_id_fkey FOREIGN KEY (lesson_id) REFERENCES lessons (id) ON DELETE CASCADE,
  CONSTRAINT lesson_access_student_id_fkey FOREIGN KEY (student_id) REFERENCES auth.users (id) ON DELETE CASCADE
);

-- 3. Create material_access table (if not exists)
CREATE TABLE IF NOT EXISTS public.material_access (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  material_id uuid NOT NULL,
  student_id uuid NOT NULL,
  accessed_at timestamp with time zone DEFAULT now(),
  CONSTRAINT material_access_material_id_fkey FOREIGN KEY (material_id) REFERENCES materials (id) ON DELETE CASCADE,
  CONSTRAINT material_access_student_id_fkey FOREIGN KEY (student_id) REFERENCES auth.users (id) ON DELETE CASCADE
);

-- 4. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_reports_user_id ON public.user_reports (user_id);
CREATE INDEX IF NOT EXISTS idx_user_reports_last_quiz_taken ON public.user_reports (last_quiz_taken);
CREATE INDEX IF NOT EXISTS idx_lesson_access_student_id ON public.lesson_access (student_id);
CREATE INDEX IF NOT EXISTS idx_lesson_access_lesson_id ON public.lesson_access (lesson_id);
CREATE INDEX IF NOT EXISTS idx_material_access_student_id ON public.material_access (student_id);
CREATE INDEX IF NOT EXISTS idx_material_access_material_id ON public.material_access (material_id);

-- 5. Enable RLS on all tables
ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.material_access ENABLE ROW LEVEL SECURITY;

-- 6. Create RLS policies for user_reports
DROP POLICY IF EXISTS "Users can view their own reports" ON public.user_reports;
CREATE POLICY "Users can view their own reports" ON public.user_reports
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own reports" ON public.user_reports;
CREATE POLICY "Users can update their own reports" ON public.user_reports
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own reports" ON public.user_reports;
CREATE POLICY "Users can insert their own reports" ON public.user_reports
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 7. Create RLS policies for lesson_access
DROP POLICY IF EXISTS "Users can view their own lesson access" ON public.lesson_access;
CREATE POLICY "Users can view their own lesson access" ON public.lesson_access
  FOR SELECT USING (auth.uid() = student_id);

DROP POLICY IF EXISTS "Users can insert their own lesson access" ON public.lesson_access;
CREATE POLICY "Users can insert their own lesson access" ON public.lesson_access
  FOR INSERT WITH CHECK (auth.uid() = student_id);

-- 8. Create RLS policies for material_access
DROP POLICY IF EXISTS "Users can view their own material access" ON public.material_access;
CREATE POLICY "Users can view their own material access" ON public.material_access
  FOR SELECT USING (auth.uid() = student_id);

DROP POLICY IF EXISTS "Users can insert their own material access" ON public.material_access;
CREATE POLICY "Users can insert their own material access" ON public.material_access
  FOR INSERT WITH CHECK (auth.uid() = student_id);

-- 9. Create functions for incrementing counters
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

-- 10. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.user_reports TO authenticated;
GRANT ALL ON public.lesson_access TO authenticated;
GRANT ALL ON public.material_access TO authenticated;
GRANT EXECUTE ON FUNCTION increment_courses_enrolled(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_lessons_accessed(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_materials_accessed(uuid) TO authenticated;

-- 11. Create a function to initialize user reports for existing users
CREATE OR REPLACE FUNCTION initialize_user_reports()
RETURNS void AS $$
DECLARE
  user_record RECORD;
BEGIN
  FOR user_record IN SELECT id FROM auth.users
  LOOP
    INSERT INTO public.user_reports (user_id, total_courses_enrolled, total_lessons_accessed, total_materials_accessed, average_quiz_score, total_quizzes)
    VALUES (user_record.id, 0, 0, 0, 0.0, 0)
    ON CONFLICT (user_id) DO NOTHING;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 12. Initialize user reports for existing users
SELECT initialize_user_reports();

-- 13. Create a trigger to automatically create user reports for new users
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.user_reports (user_id, total_courses_enrolled, total_lessons_accessed, total_materials_accessed, average_quiz_score, total_quizzes)
  VALUES (NEW.id, 0, 0, 0, 0.0, 0);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 14. Verify the setup
SELECT 'Analytics tables setup completed successfully!' as status; 