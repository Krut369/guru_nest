-- Update user_reports table structure to match analytics requirements
-- This script ensures all count fields are properly defined and working

-- Drop existing table if it exists (be careful with this in production)
-- DROP TABLE IF EXISTS user_reports;

-- Create or update user_reports table
CREATE TABLE IF NOT EXISTS user_reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  total_courses_enrolled INTEGER NULL DEFAULT 0,
  total_lessons_accessed INTEGER NULL DEFAULT 0,
  total_materials_accessed INTEGER NULL DEFAULT 0,
  average_quiz_score DOUBLE PRECISION NULL DEFAULT 0,
  last_quiz_taken TIMESTAMP WITH TIME ZONE NULL,
  total_quizzes INTEGER NULL DEFAULT 0,
  learning_streak INTEGER NULL DEFAULT 0,
  unread_messages INTEGER NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_reports_user_id ON user_reports(user_id);
CREATE INDEX IF NOT EXISTS idx_user_reports_created_at ON user_reports(created_at);

-- Enable Row Level Security (RLS)
ALTER TABLE user_reports ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY IF NOT EXISTS "Users can view their own reports" ON user_reports
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can insert their own reports" ON user_reports
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can update their own reports" ON user_reports
  FOR UPDATE USING (auth.uid() = user_id);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
CREATE TRIGGER IF NOT EXISTS update_user_reports_updated_at
  BEFORE UPDATE ON user_reports
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Create function to increment counters
CREATE OR REPLACE FUNCTION increment_user_report_counter(
  p_user_id UUID,
  p_field_name TEXT,
  p_increment INTEGER DEFAULT 1
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO user_reports (user_id, total_courses_enrolled, total_lessons_accessed, total_materials_accessed, total_quizzes)
  VALUES (p_user_id, 
    CASE WHEN p_field_name = 'total_courses_enrolled' THEN p_increment ELSE 0 END,
    CASE WHEN p_field_name = 'total_lessons_accessed' THEN p_increment ELSE 0 END,
    CASE WHEN p_field_name = 'total_materials_accessed' THEN p_increment ELSE 0 END,
    CASE WHEN p_field_name = 'total_quizzes' THEN p_increment ELSE 0 END
  )
  ON CONFLICT (user_id) DO UPDATE SET
    total_courses_enrolled = user_reports.total_courses_enrolled + 
      CASE WHEN p_field_name = 'total_courses_enrolled' THEN p_increment ELSE 0 END,
    total_lessons_accessed = user_reports.total_lessons_accessed + 
      CASE WHEN p_field_name = 'total_lessons_accessed' THEN p_increment ELSE 0 END,
    total_materials_accessed = user_reports.total_materials_accessed + 
      CASE WHEN p_field_name = 'total_materials_accessed' THEN p_increment ELSE 0 END,
    total_quizzes = user_reports.total_quizzes + 
      CASE WHEN p_field_name = 'total_quizzes' THEN p_increment ELSE 0 END,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Create function to update quiz score
CREATE OR REPLACE FUNCTION update_user_quiz_score(
  p_user_id UUID,
  p_score DOUBLE PRECISION,
  p_taken_at TIMESTAMP WITH TIME ZONE
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO user_reports (user_id, average_quiz_score, last_quiz_taken, total_quizzes)
  VALUES (p_user_id, p_score, p_taken_at, 1)
  ON CONFLICT (user_id) DO UPDATE SET
    average_quiz_score = (user_reports.average_quiz_score * user_reports.total_quizzes + p_score) / (user_reports.total_quizzes + 1),
    last_quiz_taken = p_taken_at,
    total_quizzes = user_reports.total_quizzes + 1,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Create function to update learning streak
CREATE OR REPLACE FUNCTION update_user_learning_streak(
  p_user_id UUID,
  p_streak INTEGER
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO user_reports (user_id, learning_streak)
  VALUES (p_user_id, p_streak)
  ON CONFLICT (user_id) DO UPDATE SET
    learning_streak = p_streak,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Create function to update unread messages count
CREATE OR REPLACE FUNCTION update_user_unread_messages(
  p_user_id UUID,
  p_count INTEGER
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO user_reports (user_id, unread_messages)
  VALUES (p_user_id, p_count)
  ON CONFLICT (user_id) DO UPDATE SET
    unread_messages = p_count,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Add comments for documentation
COMMENT ON TABLE user_reports IS 'Stores user analytics and progress data';
COMMENT ON COLUMN user_reports.total_courses_enrolled IS 'Total number of courses the user has enrolled in';
COMMENT ON COLUMN user_reports.total_lessons_accessed IS 'Total number of lessons the user has accessed';
COMMENT ON COLUMN user_reports.total_materials_accessed IS 'Total number of materials the user has accessed';
COMMENT ON COLUMN user_reports.average_quiz_score IS 'Average score across all quizzes taken by the user';
COMMENT ON COLUMN user_reports.last_quiz_taken IS 'Timestamp of the last quiz taken by the user';
COMMENT ON COLUMN user_reports.total_quizzes IS 'Total number of quizzes taken by the user';
COMMENT ON COLUMN user_reports.learning_streak IS 'Current consecutive days of learning activity';
COMMENT ON COLUMN user_reports.unread_messages IS 'Number of unread messages for the user';

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON user_reports TO authenticated;
GRANT USAGE ON SEQUENCE user_reports_id_seq TO authenticated; 