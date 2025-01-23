-- Drop existing policies
DROP POLICY IF EXISTS "Users can manage own documents" ON documents;

-- Create comprehensive policy for documents
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

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_documents_user_id
ON documents(user_id);

-- Ensure documents table has RLS enabled
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- Grant necessary permissions
GRANT ALL ON documents TO authenticated;