/*
  # Document Storage Setup
  
  1. Storage
    - Creates a secure storage bucket for document files
    - Sets up RLS policies for secure access
  
  2. Security
    - Only authenticated users can upload their own documents
    - Users can only read their own documents
    - Agency users can read all documents
*/

-- Create a new storage bucket for documents
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', false)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Allow users to upload their own documents
CREATE POLICY "Users can upload their own documents"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to read their own documents
CREATE POLICY "Users can read their own documents"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow agency users to read all documents
CREATE POLICY "Agency can read all documents"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'documents' AND
  auth.jwt() ->> 'role' = 'agency'
);