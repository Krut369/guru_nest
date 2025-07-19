-- Create user_goals table for tracking learning goals
CREATE TABLE IF NOT EXISTS public.user_goals (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  target_value double precision NOT NULL,
  current_value double precision DEFAULT 0,
  goal_type text NOT NULL, -- 'streak', 'lessons', 'quiz_score', 'courses'
  timeframe text NOT NULL, -- 'daily', 'weekly', 'monthly'
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  
  CONSTRAINT user_goals_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_goals_user_id ON public.user_goals(user_id);
CREATE INDEX IF NOT EXISTS idx_user_goals_goal_type ON public.user_goals(goal_type);
CREATE INDEX IF NOT EXISTS idx_user_goals_is_active ON public.user_goals(is_active);

-- Create trigger to update updated_at column
CREATE OR REPLACE FUNCTION update_user_goals_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_user_goals_updated_at
  BEFORE UPDATE ON public.user_goals
  FOR EACH ROW
  EXECUTE FUNCTION update_user_goals_updated_at();

-- Insert some default goals for existing users (optional)
-- This can be run manually if needed
/*
INSERT INTO public.user_goals (user_id, title, description, target_value, goal_type, timeframe)
SELECT 
  u.id,
  'Learning Streak',
  'Maintain a daily learning streak',
  7.0,
  'streak',
  'weekly'
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM public.user_goals g 
  WHERE g.user_id = u.id AND g.goal_type = 'streak'
);
*/ 