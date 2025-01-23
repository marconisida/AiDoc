/*
  # Storage setup for document management

  1. Changes
    - Create documents storage bucket if it doesn't exist
    - Set file size limits and allowed MIME types
    - Update RLS policies for document access

  2. Security
    - Enable RLS on storage.objects
    - Add policies for user document access
    - Ensure proper file type restrictions
*/

-- Create a new storage bucket for documents if it doesn't exist
DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
        'documents',
        'documents',
        false,
        10485760, -- 10MB limit
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']::text[]
    )
    ON CONFLICT (id) DO UPDATE
    SET 
        file_size_limit = EXCLUDED.file_size_limit,
        allowed_mime_types = EXCLUDED.allowed_mime_types;
END $$;

-- Enable RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Safely create or update policies
DO $$
BEGIN
    -- Drop existing policies if they exist
    DROP POLICY IF EXISTS "Users can upload their own documents" ON storage.objects;
    DROP POLICY IF EXISTS "Users can read their own documents" ON storage.objects;
    DROP POLICY IF EXISTS "Users can delete their own documents" ON storage.objects;
    
    -- Create new policies
    CREATE POLICY "Users can upload their own documents"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'documents' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

    CREATE POLICY "Users can read their own documents"
    ON storage.objects FOR SELECT TO authenticated
    USING (
        bucket_id = 'documents' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

    CREATE POLICY "Users can delete their own documents"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'documents' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );
END $$;