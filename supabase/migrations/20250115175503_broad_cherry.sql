-- Update storage bucket configuration
UPDATE storage.buckets
SET 
    file_size_limit = 10485760,  -- 10MB limit
    allowed_mime_types = ARRAY[
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/pdf'
    ]::text[],
    public = true
WHERE id = 'documents';

-- Drop existing storage policies
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can manage documents" ON storage.objects;
    DROP POLICY IF EXISTS "Allow public read access" ON storage.objects;
    DROP POLICY IF EXISTS "Allow authenticated upload" ON storage.objects;
    DROP POLICY IF EXISTS "Allow owners and agency to delete" ON storage.objects;
END $$;

-- Create new storage policies
CREATE POLICY "Allow public read access"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'documents');

CREATE POLICY "Allow authenticated upload"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'documents' AND
    (auth.uid()::text = (storage.foldername(name))[1] OR auth.jwt() ->> 'role' = 'agency')
);

CREATE POLICY "Allow owners and agency to delete"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'documents' AND
    (auth.uid()::text = (storage.foldername(name))[1] OR auth.jwt() ->> 'role' = 'agency')
);

-- Ensure RLS is enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;