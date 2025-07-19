-- Check Analytics Setup
-- Run this script in your Supabase SQL editor to verify the setup

-- 1. Check if tables exist
SELECT 
  table_name,
  table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('user_reports', 'lesson_access', 'material_access')
ORDER BY table_name;

-- 2. Check table structure
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'user_reports'
ORDER BY ordinal_position;

-- 3. Check if user_reports has data
SELECT 
  COUNT(*) as total_records,
  COUNT(DISTINCT user_id) as unique_users
FROM public.user_reports;

-- 4. Check sample user report data
SELECT * FROM public.user_reports LIMIT 5;

-- 5. Check RLS policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE schemaname = 'public' 
  AND tablename IN ('user_reports', 'lesson_access', 'material_access');

-- 6. Check if functions exist
SELECT 
  routine_name,
  routine_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%increment%'
ORDER BY routine_name;

-- 7. Check triggers
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers 
WHERE trigger_schema = 'public' 
  AND event_object_table IN ('user_reports', 'auth.users')
ORDER BY trigger_name; 