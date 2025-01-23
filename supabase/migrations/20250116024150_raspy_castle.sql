-- Update storage bucket configuration with proper settings
UPDATE storage.buckets
SET 
    public = true,
    file_size_limit = 10485760,  -- 10MB limit
    allowed_mime_types = ARRAY[
        'image/jpeg',
        'image/png',
        'image/webp'
    ]::text[]
WHERE id = 'documents';

-- Drop all existing storage policies to ensure clean state
DO $$
BEGIN
    DROP POLICY IF EXISTS "documents_storage_public_read" ON storage.objects;
    DROP POLICY IF EXISTS "documents_storage_auth_insert" ON storage.objects;
    DROP POLICY IF EXISTS "documents_storage_auth_delete" ON storage.objects;
    DROP POLICY IF EXISTS "storage_objects_public_read" ON storage.objects;
    DROP POLICY IF EXISTS "storage_objects_auth_insert" ON storage.objects;
    DROP POLICY IF EXISTS "storage_objects_auth_delete" ON storage.objects;
END $$;

-- Create storage policies with proper permissions
CREATE POLICY "documents_storage_select"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'documents');

CREATE POLICY "documents_storage_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'documents' AND
    (auth.uid()::text = (storage.foldername(name))[1] OR auth.jwt() ->> 'role' = 'agency')
);

CREATE POLICY "documents_storage_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'documents' AND
    (auth.uid()::text = (storage.foldername(name))[1] OR auth.jwt() ->> 'role' = 'agency')
)
WITH CHECK (
    bucket_id = 'documents' AND
    (auth.uid()::text = (storage.foldername(name))[1] OR auth.jwt() ->> 'role' = 'agency')
);

CREATE POLICY "documents_storage_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'documents' AND
    (auth.uid()::text = (storage.foldername(name))[1] OR auth.jwt() ->> 'role' = 'agency')
);

-- Ensure RLS is enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_storage_objects_bucket_name
ON storage.objects(bucket_id, name text_pattern_ops);