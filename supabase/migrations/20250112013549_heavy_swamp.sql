/*
  # Document Management System Setup

  1. Tables
    - Creates documents table for storing document analysis results
    - Adds necessary columns and constraints
  
  2. Security
    - Enables RLS
    - Adds read/write policies
  
  3. Indexing
    - Adds performance optimization index
*/

-- Create base table structure
CREATE TABLE IF NOT EXISTS documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  document_type text NOT NULL,
  analysis_result jsonb NOT NULL,
  created_at timestamptz DEFAULT now(),
  file_path text
);

-- Add foreign key separately
ALTER TABLE documents 
  ADD CONSTRAINT fk_user 
  FOREIGN KEY (user_id) 
  REFERENCES auth.users (id) 
  ON DELETE CASCADE;

-- Enable RLS
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- Create read policy
CREATE POLICY "Users can read own documents"
  ON documents
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Create insert policy
CREATE POLICY "Users can insert own documents"
  ON documents
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Add performance index
CREATE INDEX IF NOT EXISTS documents_user_id_idx 
  ON documents(user_id);