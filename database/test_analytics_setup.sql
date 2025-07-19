-- Test Analytics Setup
-- Run this script to verify all tables are working correctly

-- 1. Check if all required tables exist
SELECT 
  table_name,
  CASE 
    WHEN table_name IN ('lesson_access', 'material_access', 'materials', 'quizzes', 'quiz_results', 'messages') 
    THEN '✅ EXISTS' 
    ELSE '❌ MISSING' 
  END as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('lesson_access', 'material_access', 'materials', 'quizzes', 'quiz_results', 'messages')
ORDER BY table_name;

-- 2. Check table structures
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name IN ('lesson_access', 'material_access', 'materials', 'quizzes', 'quiz_results', 'messages')
ORDER BY table_name, ordinal_position;

-- 3. Check RLS policies
SELECT 
  tablename,
  policyname,
  permissive,
  cmd
FROM pg_policies 
WHERE schemaname = 'public' 
  AND tablename IN ('lesson_access', 'material_access', 'materials', 'quizzes', 'quiz_results', 'messages')
ORDER BY tablename, policyname;

-- 4. Check indexes
SELECT 
  tablename,
  indexname,
  indexdef
FROM pg_indexes 
WHERE schemaname = 'public' 
  AND tablename IN ('lesson_access', 'material_access', 'materials', 'quizzes', 'quiz_results', 'messages')
ORDER BY tablename, indexname;

-- 5. Test inserting sample data (if tables are empty)
-- This will help verify the tables are working correctly

-- Test lesson_access table
INSERT INTO public.lesson_access (student_id, lesson_id) 
SELECT 
  (SELECT id FROM auth.users LIMIT 1),
  (SELECT id FROM lessons LIMIT 1)
WHERE NOT EXISTS (SELECT 1 FROM public.lesson_access LIMIT 1)
ON CONFLICT DO NOTHING;

-- Test material_access table (if materials exist)
INSERT INTO public.material_access (student_id, material_id) 
SELECT 
  (SELECT id FROM auth.users LIMIT 1),
  (SELECT id FROM materials LIMIT 1)
WHERE EXISTS (SELECT 1 FROM materials LIMIT 1)
  AND NOT EXISTS (SELECT 1 FROM public.material_access LIMIT 1)
ON CONFLICT DO NOTHING;

-- Test quiz_results table (if quizzes exist)
INSERT INTO public.quiz_results (student_id, quiz_id, score) 
SELECT 
  (SELECT id FROM auth.users LIMIT 1),
  (SELECT id FROM quizzes LIMIT 1),
  85.5
WHERE EXISTS (SELECT 1 FROM quizzes LIMIT 1)
  AND NOT EXISTS (SELECT 1 FROM public.quiz_results LIMIT 1)
ON CONFLICT DO NOTHING;

-- 6. Show current data counts
SELECT 
  'lesson_access' as table_name,
  COUNT(*) as record_count
FROM public.lesson_access
UNION ALL
SELECT 
  'material_access' as table_name,
  COUNT(*) as record_count
FROM public.material_access
UNION ALL
SELECT 
  'materials' as table_name,
  COUNT(*) as record_count
FROM public.materials
UNION ALL
SELECT 
  'quizzes' as table_name,
  COUNT(*) as record_count
FROM public.quizzes
UNION ALL
SELECT 
  'quiz_results' as table_name,
  COUNT(*) as record_count
FROM public.quiz_results
UNION ALL
SELECT 
  'messages' as table_name,
  COUNT(*) as record_count
FROM public.messages
ORDER BY table_name;

-- 7. Test foreign key relationships
SELECT 
  'lesson_access -> lessons' as relationship,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM public.lesson_access la
      LEFT JOIN lessons l ON la.lesson_id = l.id
      WHERE l.id IS NULL
    ) THEN '❌ BROKEN'
    ELSE '✅ VALID'
  END as status
UNION ALL
SELECT 
  'material_access -> materials' as relationship,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM public.material_access ma
      LEFT JOIN materials m ON ma.material_id = m.id
      WHERE m.id IS NULL
    ) THEN '❌ BROKEN'
    ELSE '✅ VALID'
  END as status
UNION ALL
SELECT 
  'quiz_results -> quizzes' as relationship,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM public.quiz_results qr
      LEFT JOIN quizzes q ON qr.quiz_id = q.id
      WHERE q.id IS NULL
    ) THEN '❌ BROKEN'
    ELSE '✅ VALID'
  END as status; 