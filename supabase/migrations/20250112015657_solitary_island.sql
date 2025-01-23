/*
  # Fix storage setup for document uploads

  1. Changes
    - Updates storage bucket configuration with proper limits and MIME types
    - Ensures proper RLS policies for document access
    - Adds missing agency access policy

  2. Security
    - Maintains RLS enforcement
    - Updates policies for proper user access control
    - Adds agency role access policy
*/

-- Update storage bucket configuration
UPDATE storage.buckets
SET 
    file_size_limit = 10485760,  -- 10MB limit
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']::text[]
WHERE id = 'documents';

-- Ensure agency role policy exists
DO $$
BEGIN
    DROP POLICY IF EXISTS "Agency can read all documents" ON storage.objects;
    
    CREATE POLICY "Agency can read all documents"
    ON storage.objects FOR SELECT TO authenticated
    USING (
        bucket_id = 'documents' AND
        auth.jwt() ->> 'role' = 'agency'
    );
END $$;