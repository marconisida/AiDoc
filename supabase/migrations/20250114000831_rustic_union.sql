/*
  # Fix Chat View and Functions

  1. Changes
    - Create a secure function to get chat conversations with user information
    - Add proper indexes for performance
    - Add helper functions for unread counts
*/

-- Create function to get unread count for a conversation
CREATE OR REPLACE FUNCTION get_conversation_unread_count(conversation_id uuid)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT COUNT(*)::integer
  FROM chat_messages
  WHERE conversation_id = $1
  AND read_at IS NULL
  AND sender_type != 'agency';
$$;

-- Create secure function to get conversations with user info
CREATE OR REPLACE FUNCTION get_chat_conversations(
  p_status text DEFAULT 'active'
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  agency_id uuid,
  status text,
  last_message text,
  last_message_at timestamptz,
  is_bot_active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  user_email text,
  agency_email text,
  unread_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF auth.jwt() ->> 'role' = 'agency' THEN
    RETURN QUERY
    SELECT 
      c.id,
      c.user_id,
      c.agency_id,
      c.status,
      c.last_message,
      c.last_message_at,
      c.is_bot_active,
      c.created_at,
      c.updated_at,
      u.email::text as user_email,
      a.email::text as agency_email,
      get_conversation_unread_count(c.id) as unread_count
    FROM chat_conversations c
    LEFT JOIN auth.users u ON c.user_id = u.id
    LEFT JOIN auth.users a ON c.agency_id = a.id
    WHERE c.status = p_status
    ORDER BY c.updated_at DESC;
  ELSE
    RETURN QUERY
    SELECT 
      c.id,
      c.user_id,
      c.agency_id,
      c.status,
      c.last_message,
      c.last_message_at,
      c.is_bot_active,
      c.created_at,
      c.updated_at,
      u.email::text as user_email,
      a.email::text as agency_email,
      get_conversation_unread_count(c.id) as unread_count
    FROM chat_conversations c
    LEFT JOIN auth.users u ON c.user_id = u.id
    LEFT JOIN auth.users a ON c.agency_id = a.id
    WHERE c.user_id = auth.uid()
    AND c.status = p_status
    ORDER BY c.updated_at DESC;
  END IF;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_chat_conversations(text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_conversation_unread_count(uuid) TO authenticated;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_read
  ON chat_messages(conversation_id, read_at)
  WHERE read_at IS NULL;