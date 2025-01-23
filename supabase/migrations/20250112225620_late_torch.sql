-- Drop existing storage policies
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can upload their own documents" ON storage.objects;
    DROP POLICY IF EXISTS "Users can read their own documents" ON storage.objects;
    DROP POLICY IF EXISTS "Users can delete their own documents" ON storage.objects;
    DROP POLICY IF EXISTS "Agency can read all documents" ON storage.objects;
END $$;

-- Create comprehensive storage policies
CREATE POLICY "Users and agency can manage documents"
ON storage.objects
FOR ALL 
TO authenticated
USING (
    bucket_id = 'documents' AND (
        (storage.foldername(name))[1] = auth.uid()::text OR
        auth.jwt() ->> 'role' = 'agency'
    )
)
WITH CHECK (
    bucket_id = 'documents' AND (
        (storage.foldername(name))[1] = auth.uid()::text OR
        auth.jwt() ->> 'role' = 'agency'
    )
);

-- Update bucket configuration
UPDATE storage.buckets
SET public = false,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY[
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/pdf'
    ]::text[]
WHERE id = 'documents';