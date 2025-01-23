/*
  # Fix Chat Policies Without Breaking Changes

  1. Changes
    - Add new policies that work alongside existing ones
    - Maintain backward compatibility
    - Fix conversation access issues

  2. Security
    - Preserve existing security model
    - Add additional safeguards
*/

-- Create additional policies for chat_conversations
CREATE POLICY "Users can manage own active conversations"
ON chat_conversations
FOR ALL
TO authenticated
USING (
  (user_id = auth.uid() AND status = 'active') OR 
  (agency_id = auth.uid() AND status = 'active') OR 
  auth.jwt() ->> 'role' = 'agency'
)
WITH CHECK (
  (user_id = auth.uid() AND status = 'active') OR 
  (agency_id = auth.uid() AND status = 'active') OR 
  auth.jwt() ->> 'role' = 'agency'
);

-- Create additional policies for chat_messages
CREATE POLICY "Users can manage messages in active conversations"
ON chat_messages
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM chat_conversations c
    WHERE c.id = conversation_id
    AND c.status = 'active'
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
    AND c.status = 'active'
    AND (
      c.user_id = auth.uid() OR 
      c.agency_id = auth.uid() OR 
      auth.jwt() ->> 'role' = 'agency'
    )
  )
);

-- Create additional policies for chat_participants
CREATE POLICY "Users can manage participants in active conversations"
ON chat_participants
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM chat_conversations c
    WHERE c.id = conversation_id
    AND c.status = 'active'
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
    AND c.status = 'active'
    AND (
      c.user_id = auth.uid() OR 
      c.agency_id = auth.uid() OR 
      auth.jwt() ->> 'role' = 'agency'
    )
  )
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chat_conversations_status_user
ON chat_conversations(status, user_id);

CREATE INDEX IF NOT EXISTS idx_chat_conversations_status_agency
ON chat_conversations(status, agency_id);

CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_created
ON chat_messages(conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_participants_conversation_user
ON chat_participants(conversation_id, user_id);