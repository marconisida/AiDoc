-- Update storage bucket to be public but maintain RLS
UPDATE storage.buckets
SET public = true
WHERE id = 'documents';

-- Drop existing policies
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users and agency can manage documents" ON storage.objects;
END $$;

-- Create separate policies for better control
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

-- Update bucket configuration
UPDATE storage.buckets
SET allowed_mime_types = ARRAY[
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf'
]::text[],
    file_size_limit = 10485760
WHERE id = 'documents';