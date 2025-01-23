-- Drop existing policies
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Users can view own conversations" ON chat_conversations;
  DROP POLICY IF EXISTS "Users can create own conversations" ON chat_conversations;
  DROP POLICY IF EXISTS "Users can update own conversations" ON chat_conversations;
END $$;

-- Create simplified policies for chat_conversations
CREATE POLICY "Users can view own conversations"
ON chat_conversations
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid() OR 
  agency_id = auth.uid() OR 
  auth.jwt() ->> 'role' = 'agency'
);

CREATE POLICY "Users can create conversations"
ON chat_conversations
FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
);

CREATE POLICY "Users can update own conversations"
ON chat_conversations
FOR UPDATE
TO authenticated
USING (
  user_id = auth.uid() OR 
  agency_id = auth.uid() OR 
  auth.jwt() ->> 'role' = 'agency'
)
WITH CHECK (
  user_id = auth.uid() OR 
  agency_id = auth.uid() OR 
  auth.jwt() ->> 'role' = 'agency'
);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_chat_conversations_user_status
ON chat_conversations(user_id, status);