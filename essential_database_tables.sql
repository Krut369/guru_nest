-- Essential Database Tables for Analytics
-- This script defines the core tables needed for the analytics system
-- All analytics data is calculated directly from these tables

-- Users table (if not already exists)
CREATE TABLE IF NOT EXISTS users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  role TEXT DEFAULT 'student',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Courses table
CREATE TABLE IF NOT EXISTS courses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  category TEXT,
  price DOUBLE PRECISION DEFAULT 0.0,
  teacher_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enrollments table (tracks course enrollments)
CREATE TABLE IF NOT EXISTS enrollments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(student_id, course_id)
);

-- Lessons table
CREATE TABLE IF NOT EXISTS lessons (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT,
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  order_index INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Lesson access table (tracks when students access lessons)
CREATE TABLE IF NOT EXISTS lesson_access (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  accessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Materials table
CREATE TABLE IF NOT EXISTS materials (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  file_url TEXT,
  file_type TEXT,
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Material access table (tracks when students access materials)
CREATE TABLE IF NOT EXISTS material_access (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  material_id UUID NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
  accessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Quizzes table
CREATE TABLE IF NOT EXISTS quizzes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Quiz results table (tracks quiz performance)
CREATE TABLE IF NOT EXISTS quiz_results (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  score DOUBLE PRECISION NOT NULL,
  taken_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Messages table (for unread message count)
CREATE TABLE IF NOT EXISTS messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_enrollments_student_id ON enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_course_id ON enrollments(course_id);
CREATE INDEX IF NOT EXISTS idx_lesson_access_student_id ON lesson_access(student_id);
CREATE INDEX IF NOT EXISTS idx_lesson_access_accessed_at ON lesson_access(accessed_at);
CREATE INDEX IF NOT EXISTS idx_material_access_student_id ON material_access(student_id);
CREATE INDEX IF NOT EXISTS idx_material_access_accessed_at ON material_access(accessed_at);
CREATE INDEX IF NOT EXISTS idx_quiz_results_student_id ON quiz_results(student_id);
CREATE INDEX IF NOT EXISTS idx_quiz_results_taken_at ON quiz_results(taken_at);
CREATE INDEX IF NOT EXISTS idx_messages_recipient_id ON messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_messages_read ON messages(read);

-- Enable Row Level Security (RLS) on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE material_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for users table
CREATE POLICY IF NOT EXISTS "Users can view their own profile" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY IF NOT EXISTS "Users can update their own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

-- Create RLS policies for courses table
CREATE POLICY IF NOT EXISTS "Anyone can view courses" ON courses
  FOR SELECT USING (true);

CREATE POLICY IF NOT EXISTS "Teachers can manage their own courses" ON courses
  FOR ALL USING (auth.uid() = teacher_id);

-- Create RLS policies for enrollments table
CREATE POLICY IF NOT EXISTS "Students can view their own enrollments" ON enrollments
  FOR SELECT USING (auth.uid() = student_id);

CREATE POLICY IF NOT EXISTS "Students can enroll in courses" ON enrollments
  FOR INSERT WITH CHECK (auth.uid() = student_id);

-- Create RLS policies for lesson_access table
CREATE POLICY IF NOT EXISTS "Students can view their own lesson access" ON lesson_access
  FOR SELECT USING (auth.uid() = student_id);

CREATE POLICY IF NOT EXISTS "Students can record lesson access" ON lesson_access
  FOR INSERT WITH CHECK (auth.uid() = student_id);

-- Create RLS policies for material_access table
CREATE POLICY IF NOT EXISTS "Students can view their own material access" ON material_access
  FOR SELECT USING (auth.uid() = student_id);

CREATE POLICY IF NOT EXISTS "Students can record material access" ON material_access
  FOR INSERT WITH CHECK (auth.uid() = student_id);

-- Create RLS policies for quiz_results table
CREATE POLICY IF NOT EXISTS "Students can view their own quiz results" ON quiz_results
  FOR SELECT USING (auth.uid() = student_id);

CREATE POLICY IF NOT EXISTS "Students can record quiz results" ON quiz_results
  FOR INSERT WITH CHECK (auth.uid() = student_id);

-- Create RLS policies for messages table
CREATE POLICY IF NOT EXISTS "Users can view messages they sent or received" ON messages
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

CREATE POLICY IF NOT EXISTS "Users can send messages" ON messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY IF NOT EXISTS "Users can update messages they received" ON messages
  FOR UPDATE USING (auth.uid() = recipient_id);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers to automatically update updated_at
CREATE TRIGGER IF NOT EXISTS update_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER IF NOT EXISTS update_courses_updated_at
  BEFORE UPDATE ON courses
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER IF NOT EXISTS update_lessons_updated_at
  BEFORE UPDATE ON lessons
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON users TO authenticated;
GRANT SELECT, INSERT, UPDATE ON courses TO authenticated;
GRANT SELECT, INSERT ON enrollments TO authenticated;
GRANT SELECT, INSERT ON lesson_access TO authenticated;
GRANT SELECT, INSERT ON material_access TO authenticated;
GRANT SELECT, INSERT ON quiz_results TO authenticated;
GRANT SELECT, INSERT, UPDATE ON messages TO authenticated;

-- Add comments for documentation
COMMENT ON TABLE users IS 'Stores user account information';
COMMENT ON TABLE courses IS 'Stores course information';
COMMENT ON TABLE enrollments IS 'Tracks student course enrollments';
COMMENT ON TABLE lessons IS 'Stores lesson content for courses';
COMMENT ON TABLE lesson_access IS 'Tracks when students access lessons';
COMMENT ON TABLE materials IS 'Stores course materials and resources';
COMMENT ON TABLE material_access IS 'Tracks when students access materials';
COMMENT ON TABLE quizzes IS 'Stores quiz information';
COMMENT ON TABLE quiz_results IS 'Tracks student quiz performance';
COMMENT ON TABLE messages IS 'Stores user messages for communication'; 