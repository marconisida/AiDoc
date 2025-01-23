-- Drop existing policies
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Users can view their conversations" ON chat_conversations;
  DROP POLICY IF EXISTS "Users can create conversations" ON chat_conversations;
  DROP POLICY IF EXISTS "Users can view conversation messages" ON chat_messages;
  DROP POLICY IF EXISTS "Users can send messages" ON chat_messages;
  DROP POLICY IF EXISTS "Users can view participants" ON chat_participants;
  DROP POLICY IF EXISTS "Users can join conversations" ON chat_participants;
END $$;

-- Create comprehensive policies for chat_conversations
CREATE POLICY "Users can manage conversations"
ON chat_conversations
FOR ALL
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

-- Create comprehensive policies for chat_messages
CREATE POLICY "Users can manage messages"
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

-- Create comprehensive policies for chat_participants
CREATE POLICY "Users can manage participants"
ON chat_participants
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