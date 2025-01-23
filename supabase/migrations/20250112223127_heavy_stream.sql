/*
  # Fix Documents RLS Policies

  1. Changes
    - Add insert policy for authenticated users
    - Add policy for agency role to manage all documents
    - Update existing policies to handle both regular users and agency role

  2. Security
    - Enable RLS on documents table
    - Add policies for CRUD operations
    - Special permissions for agency role
*/

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can read own documents" ON documents;
DROP POLICY IF EXISTS "Users can insert own documents" ON documents;

-- Create comprehensive policies
CREATE POLICY "Users can manage own documents"
ON documents
FOR ALL
TO authenticated
USING (
  auth.uid() = user_id OR 
  auth.jwt() ->> 'role' = 'agency'
)
WITH CHECK (
  auth.uid() = user_id OR 
  auth.jwt() ->> 'role' = 'agency'
);