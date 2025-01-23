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
DO $$
BEGIN
    -- Drop all possible existing policies to ensure clean state
    DROP POLICY IF EXISTS "documents_public_select" ON storage.objects;
    DROP POLICY IF EXISTS "documents_auth_insert" ON storage.objects;
    DROP POLICY IF EXISTS "documents_auth_delete" ON storage.objects;
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
    DROP POLICY IF EXISTS "storage_objects_public_read" ON storage.objects;
    DROP POLICY IF EXISTS "storage_objects_auth_insert" ON storage.objects;
    DROP POLICY IF EXISTS "storage_objects_auth_delete" ON storage.objects;
END $$;

-- Create new storage policies with unique names
DO $$
BEGIN
  -- Create policies only if they don't exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'documents_storage_public_read'
  ) THEN
    CREATE POLICY "documents_storage_public_read"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'documents');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'documents_storage_auth_insert'
  ) THEN
    CREATE POLICY "documents_storage_auth_insert"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'documents' AND
        (auth.uid()::text = (storage.foldername(name))[1] OR auth.jwt() ->> 'role' = 'agency')
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'documents_storage_auth_delete'
  ) THEN
    CREATE POLICY "documents_storage_auth_delete"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'documents' AND
        (auth.uid()::text = (storage.foldername(name))[1] OR auth.jwt() ->> 'role' = 'agency')
    );
  END IF;
END $$;

-- Ensure RLS is enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Create index for better performance if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND indexname = 'idx_storage_objects_name_bucket'
  ) THEN
    CREATE INDEX idx_storage_objects_name_bucket
      ON storage.objects(name text_pattern_ops, bucket_id);
  END IF;
END $$;