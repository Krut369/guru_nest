-- Add description column to lessons table
ALTER TABLE public.lessons
ADD COLUMN description text NULL;

-- Update existing lessons to have a default description
UPDATE public.lessons
SET description = 'No description available'
WHERE description IS NULL;

-- Add comment to the description column
COMMENT ON COLUMN public.lessons.description IS 'Description of the lesson'; 