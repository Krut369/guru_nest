-- Setup Storage Buckets and Policies for Guru Nest
-- Run this script in your Supabase SQL editor

-- Note: Storage buckets need to be created manually in the Supabase dashboard
-- This script only sets up the policies

-- 1. Create storage policies for avatars bucket
-- Allow authenticated users to upload avatars
CREATE POLICY "Users can upload avatars" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars' AND 
    auth.role() = 'authenticated'
  );

-- Allow authenticated users to update their own avatars
CREATE POLICY "Users can update avatars" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'avatars' AND 
    auth.role() = 'authenticated'
  );

-- Allow public read access to avatars
CREATE POLICY "Public can view avatars" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

-- Allow authenticated users to delete their own avatars
CREATE POLICY "Users can delete avatars" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'avatars' AND 
    auth.role() = 'authenticated'
  );

-- 2. Create storage policies for courses bucket
-- Allow authenticated users to upload course images
CREATE POLICY "Users can upload course images" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'courses' AND 
    auth.role() = 'authenticated'
  );

-- Allow public read access to course images
CREATE POLICY "Public can view course images" ON storage.objects
  FOR SELECT USING (bucket_id = 'courses');

-- 3. Create storage policies for materials bucket
-- Allow authenticated users to upload materials
CREATE POLICY "Users can upload materials" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'materials' AND 
    auth.role() = 'authenticated'
  );

-- Allow authenticated users to read materials
CREATE POLICY "Authenticated users can view materials" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'materials' AND 
    auth.role() = 'authenticated'
  );

-- 4. Create storage policies for categories bucket
-- Allow authenticated users to upload category icons
CREATE POLICY "Users can upload category icons" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'categories' AND 
    auth.role() = 'authenticated'
  );

-- Allow public read access to category icons
CREATE POLICY "Public can view category icons" ON storage.objects
  FOR SELECT USING (bucket_id = 'categories');

-- 5. Enable Row Level Security on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 6. Create a function to check if user owns the file (for avatars)
CREATE OR REPLACE FUNCTION storage.check_avatar_ownership(user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM storage.objects 
    WHERE bucket_id = 'avatars' 
    AND name LIKE 'avatar_' || user_id || '%'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Update avatar policies to check ownership
DROP POLICY IF EXISTS "Users can update avatars" ON storage.objects;
CREATE POLICY "Users can update their own avatars" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'avatars' AND 
    auth.role() = 'authenticated' AND
    storage.check_avatar_ownership(auth.uid())
  );

DROP POLICY IF EXISTS "Users can delete avatars" ON storage.objects;
CREATE POLICY "Users can delete their own avatars" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'avatars' AND 
    auth.role() = 'authenticated' AND
    storage.check_avatar_ownership(auth.uid())
  ); 