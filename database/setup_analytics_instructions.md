# Analytics Setup Instructions

## Step 1: Create Missing Tables

Run the following SQL script in your Supabase SQL editor:

```sql
-- Create missing analytics tables for 7-day progress trend
-- Run this script in your Supabase SQL editor

-- 1. Create lesson_access table to track when students view lessons
CREATE TABLE IF NOT EXISTS public.lesson_access (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  student_id uuid NOT NULL,
  lesson_id uuid NOT NULL,
  accessed_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT lesson_access_pkey PRIMARY KEY (id),
  CONSTRAINT lesson_access_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT lesson_access_lesson_id_fkey FOREIGN KEY (lesson_id) REFERENCES public.lessons(id) ON DELETE CASCADE
);

-- 2. Create material_access table to track when students download materials
CREATE TABLE IF NOT EXISTS public.material_access (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  student_id uuid NOT NULL,
  material_id uuid NOT NULL,
  accessed_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT material_access_pkey PRIMARY KEY (id),
  CONSTRAINT material_access_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT material_access_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.materials(id) ON DELETE CASCADE
);

-- 3. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_lesson_access_student_id ON public.lesson_access(student_id);
CREATE INDEX IF NOT EXISTS idx_lesson_access_accessed_at ON public.lesson_access(accessed_at);
CREATE INDEX IF NOT EXISTS idx_lesson_access_lesson_id ON public.lesson_access(lesson_id);

CREATE INDEX IF NOT EXISTS idx_material_access_student_id ON public.material_access(student_id);
CREATE INDEX IF NOT EXISTS idx_material_access_accessed_at ON public.material_access(accessed_at);
CREATE INDEX IF NOT EXISTS idx_material_access_material_id ON public.material_access(material_id);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.lesson_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.material_access ENABLE ROW LEVEL SECURITY;

-- 5. Create RLS policies for lesson_access
CREATE POLICY IF NOT EXISTS "Users can view their own lesson access" ON public.lesson_access
  FOR SELECT USING (auth.uid() = student_id);

CREATE POLICY IF NOT EXISTS "Users can insert their own lesson access" ON public.lesson_access
  FOR INSERT WITH CHECK (auth.uid() = student_id);

-- 6. Create RLS policies for material_access
CREATE POLICY IF NOT EXISTS "Users can view their own material access" ON public.material_access
  FOR SELECT USING (auth.uid() = student_id);

CREATE POLICY IF NOT EXISTS "Users can insert their own material access" ON public.material_access
  FOR INSERT WITH CHECK (auth.uid() = student_id);

-- 7. Grant necessary permissions
GRANT ALL ON public.lesson_access TO authenticated;
GRANT ALL ON public.material_access TO authenticated;
```

## Step 2: Test the Setup

After running the above script, test that the tables were created successfully:

```sql
-- Check if tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('lesson_access', 'material_access')
ORDER BY table_name;

-- Check table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'lesson_access'
ORDER BY ordinal_position;
```

## Step 3: Update Your Flutter App

The analytics service has been updated to work with your actual database schema. The changes include:

1. **Graceful handling of missing tables** - If `lesson_access` or `material_access` don't exist, it falls back to using `lesson_progress`
2. **Correct column references** - Updated to use `category_id` instead of `category`
3. **Proper data type handling** - Handles both `int` and `double` quiz scores
4. **Fallback mechanisms** - Uses available data when some tables are missing

## Step 4: Test the Analytics

1. **Restart your Flutter app**
2. **Navigate to the analytics section**
3. **Use the test buttons** to create sample data:
   - "Create Test Data" - Creates basic activity data
   - "Create Trend Data" - Creates 7-day progress trend data

## Expected Results

After setup, you should see:
- ✅ No more database errors
- ✅ Real analytics data from your database
- ✅ 7-day progress trend working
- ✅ Learning streak calculation working
- ✅ Quiz statistics displaying correctly

## Troubleshooting

If you still see errors:
1. **Check table creation** - Verify the tables were created successfully
2. **Check permissions** - Ensure RLS policies are in place
3. **Check foreign keys** - Verify the foreign key relationships are correct
4. **Restart the app** - Sometimes changes need a fresh start

The analytics system will work with your current database structure and gracefully handle any missing components! 