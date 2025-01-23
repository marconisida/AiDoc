-- Drop existing mark_messages_as_read functions
DROP FUNCTION IF EXISTS mark_messages_as_read(uuid);
DROP FUNCTION IF EXISTS mark_messages_as_read(uuid, uuid);

-- Create a single, clear function for marking messages as read
CREATE OR REPLACE FUNCTION mark_messages_as_read(
  p_conversation_id uuid,
  p_up_to_message_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  UPDATE chat_messages
  SET read_at = NOW()
  WHERE conversation_id = p_conversation_id
  AND read_at IS NULL
  AND (
    -- Agency can mark user messages as read
    (auth.jwt() ->> 'role' = 'agency' AND sender_type != 'agency')
    OR
    -- Users can mark agency messages as read
    (auth.uid() IN (
      SELECT user_id 
      FROM chat_conversations 
      WHERE id = p_conversation_id
    ) AND sender_type = 'agency')
  )
  AND (p_up_to_message_id IS NULL OR id <= p_up_to_message_id);
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION mark_messages_as_read(uuid, uuid) TO authenticated;