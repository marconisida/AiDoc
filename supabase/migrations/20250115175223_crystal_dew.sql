-- Drop existing policies
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Users can view own conversations" ON chat_conversations;
  DROP POLICY IF EXISTS "Users can insert conversations" ON chat_conversations;
  DROP POLICY IF EXISTS "Users can update own conversations" ON chat_conversations;
  DROP POLICY IF EXISTS "Users can manage own messages" ON chat_messages;
  DROP POLICY IF EXISTS "Users can manage own participants" ON chat_participants;
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

CREATE POLICY "Users can create own conversations"
ON chat_conversations
FOR INSERT
TO authenticated
WITH CHECK (
  CASE
    WHEN auth.jwt() ->> 'role' = 'agency' THEN true
    ELSE user_id = auth.uid() AND agency_id IS NULL
  END
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

-- Create simplified policies for chat_messages
CREATE POLICY "Users can manage own messages"
ON chat_messages
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM chat_conversations c
    WHERE c.id = conversation_id
    AND (
      c.user_id = auth.uid() OR 
      c.agency_id = auth.uid() OR 
      auth.jwt() ->> 'role' = 'agency'
    )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM chat_conversations c
    WHERE c.id = conversation_id
    AND (
      c.user_id = auth.uid() OR 
      c.agency_id = auth.uid() OR 
      auth.jwt() ->> 'role' = 'agency'
    )
  )
);

-- Create simplified policies for chat_participants
CREATE POLICY "Users can manage own participants"
ON chat_participants
FOR ALL
TO authenticated
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM chat_conversations c
    WHERE c.id = conversation_id
    AND (
      c.user_id = auth.uid() OR 
      c.agency_id = auth.uid() OR 
      auth.jwt() ->> 'role' = 'agency'
    )
  )
)
WITH CHECK (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM chat_conversations c
    WHERE c.id = conversation_id
    AND (
      c.user_id = auth.uid() OR 
      c.agency_id = auth.uid() OR 
      auth.jwt() ->> 'role' = 'agency'
    )
  )
);

-- Ensure RLS is enabled
ALTER TABLE chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_participants ENABLE ROW LEVEL SECURITY;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chat_conversations_user_agency
ON chat_conversations(user_id, agency_id);

CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation
ON chat_messages(conversation_id);

CREATE INDEX IF NOT EXISTS idx_chat_participants_conversation
ON chat_participants(conversation_id);

-- Grant necessary permissions
GRANT ALL ON chat_conversations TO authenticated;
GRANT ALL ON chat_messages TO authenticated;
GRANT ALL ON chat_participants TO authenticated;