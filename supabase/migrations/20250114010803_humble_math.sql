/*
  # Fix chat permissions and materialized view access

  1. Changes
    - Remove materialized view in favor of a more secure function-based approach
    - Add proper security definer functions
    - Ensure proper permissions for all users

  2. Security
    - All functions run with security definer
    - Proper RLS policies maintained
    - No direct table access required
*/

-- Drop existing objects to clean up
DROP TRIGGER IF EXISTS refresh_conversation_stats_trigger ON chat_messages;
DROP MATERIALIZED VIEW IF EXISTS conversation_stats;
DROP FUNCTION IF EXISTS refresh_conversation_stats();

-- Create a secure function to get conversations with read status
CREATE OR REPLACE FUNCTION get_conversations_with_status()
RETURNS TABLE (
  id uuid,
  user_id uuid,
  user_email text,
  last_message text,
  last_message_at timestamptz,
  unread_count bigint,
  is_read boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  -- Return different results based on user role
  IF auth.jwt() ->> 'role' = 'agency' THEN
    RETURN QUERY
    SELECT 
      c.id,
      c.user_id,
      u.email::text as user_email,
      c.last_message,
      c.last_message_at,
      COUNT(m.id) FILTER (WHERE m.read_at IS NULL AND m.sender_type != 'agency') as unread_count,
      COALESCE(bool_and(m.read_at IS NOT NULL OR m.sender_type = 'agency'), true) as is_read
    FROM chat_conversations c
    LEFT JOIN auth.users u ON c.user_id = u.id
    LEFT JOIN chat_messages m ON c.id = m.conversation_id
    WHERE c.status = 'active'
    GROUP BY c.id, c.user_id, u.email, c.last_message, c.last_message_at
    ORDER BY c.last_message_at DESC NULLS LAST;
  ELSE
    -- Regular users only see their own conversations
    RETURN QUERY
    SELECT 
      c.id,
      c.user_id,
      u.email::text as user_email,
      c.last_message,
      c.last_message_at,
      COUNT(m.id) FILTER (WHERE m.read_at IS NULL AND m.sender_type = 'agency') as unread_count,
      COALESCE(bool_and(m.read_at IS NOT NULL OR m.sender_type = 'user'), true) as is_read
    FROM chat_conversations c
    LEFT JOIN auth.users u ON c.user_id = u.id
    LEFT JOIN chat_messages m ON c.id = m.conversation_id
    WHERE c.status = 'active'
    AND c.user_id = auth.uid()
    GROUP BY c.id, c.user_id, u.email, c.last_message, c.last_message_at
    ORDER BY c.last_message_at DESC NULLS LAST;
  END IF;
END;
$$;

-- Create function to get unread count for a specific conversation
CREATE OR REPLACE FUNCTION get_conversation_unread_count(
  conversation_id uuid,
  for_agency boolean DEFAULT false
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_count bigint;
BEGIN
  SELECT COUNT(*)
  INTO v_count
  FROM chat_messages m
  JOIN chat_conversations c ON c.id = m.conversation_id
  WHERE m.conversation_id = get_conversation_unread_count.conversation_id
  AND m.read_at IS NULL
  AND (
    (for_agency AND m.sender_type != 'agency' AND (auth.jwt() ->> 'role' = 'agency' OR c.agency_id = auth.uid()))
    OR
    (NOT for_agency AND m.sender_type = 'agency' AND c.user_id = auth.uid())
  );
  
  RETURN v_count;
END;
$$;

-- Create function to mark messages as read
CREATE OR REPLACE FUNCTION mark_messages_as_read(
  p_conversation_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  -- Only update messages that the current user should be able to mark as read
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
  );
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_conversations_with_status() TO authenticated;
GRANT EXECUTE ON FUNCTION get_conversation_unread_count(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION mark_messages_as_read(uuid) TO authenticated;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_read
ON chat_messages(conversation_id, read_at, sender_type)
WHERE read_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_conversations_last_message
ON chat_conversations(last_message_at DESC NULLS LAST);