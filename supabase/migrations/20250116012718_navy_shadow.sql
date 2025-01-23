-- Update storage bucket configuration
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

-- Drop existing storage policies
DROP POLICY IF EXISTS "storage_public_read" ON storage.objects;
DROP POLICY IF EXISTS "storage_authenticated_insert" ON storage.objects;
DROP POLICY IF EXISTS "storage_owner_delete" ON storage.objects;
DROP POLICY IF EXISTS "Users can manage documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read access" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated upload" ON storage.objects;
DROP POLICY IF EXISTS "Allow owners and agency to delete" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Agency can read all documents" ON storage.objects;

-- Create simplified storage policies
CREATE POLICY "documents_public_select"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'documents');

CREATE POLICY "documents_auth_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'documents' AND
    (auth.uid()::text = (storage.foldername(name))[1] OR auth.jwt() ->> 'role' = 'agency')
);

CREATE POLICY "documents_auth_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'documents' AND
    (auth.uid()::text = (storage.foldername(name))[1] OR auth.jwt() ->> 'role' = 'agency')
);

-- Ensure RLS is enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_storage_objects_name_bucket
ON storage.objects(name text_pattern_ops, bucket_id);