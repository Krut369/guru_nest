-- Create user_login_tracking table to track daily logins
CREATE TABLE IF NOT EXISTS public.user_login_tracking (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  login_date date NOT NULL DEFAULT CURRENT_DATE,
  login_count integer DEFAULT 1,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_login_tracking_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT user_login_tracking_unique_user_date UNIQUE (user_id, login_date)
) TABLESPACE pg_default;

-- Create index for fast lookups
CREATE INDEX IF NOT EXISTS idx_user_login_tracking_user_date ON public.user_login_tracking (user_id, login_date) TABLESPACE pg_default;

-- Create trigger to update updated_at column
CREATE TRIGGER update_user_login_tracking_updated_at BEFORE
UPDATE ON user_login_tracking FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Function to record user login
CREATE OR REPLACE FUNCTION record_user_login(user_uuid uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO user_login_tracking (user_id, login_date, login_count)
  VALUES (user_uuid, CURRENT_DATE, 1)
  ON CONFLICT (user_id, login_date) 
  DO UPDATE SET 
    login_count = user_login_tracking.login_count + 1,
    updated_at = NOW();
    
  -- Update learning streak after recording login
  PERFORM update_learning_streak_with_login(user_uuid);
END;
$$ LANGUAGE plpgsql;

-- Updated learning streak function that includes login activity
CREATE OR REPLACE FUNCTION update_learning_streak_with_login(user_uuid uuid)
RETURNS void AS $$
DECLARE
  streak_count integer := 0;
  current_date date := CURRENT_DATE;
  activity_date date;
BEGIN
  -- Get all unique activity dates from lesson_access, material_access, quiz_results, and login_tracking
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
    UNION
    SELECT DISTINCT login_date as activity_date
    FROM user_login_tracking 
    WHERE user_id = user_uuid
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

-- Function to get user's current learning streak including login activity
CREATE OR REPLACE FUNCTION get_user_learning_streak(user_uuid uuid)
RETURNS integer AS $$
DECLARE
  streak_count integer := 0;
  current_date date := CURRENT_DATE;
  activity_date date;
BEGIN
  -- Get all unique activity dates from lesson_access, material_access, quiz_results, and login_tracking
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
    UNION
    SELECT DISTINCT login_date as activity_date
    FROM user_login_tracking 
    WHERE user_id = user_uuid
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
  
  RETURN streak_count;
END;
$$ LANGUAGE plpgsql; 