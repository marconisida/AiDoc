/*
  # Fix chat function ambiguity

  1. Changes
    - Rename functions to avoid ambiguity
    - Update function signatures to be unique
    - Maintain existing functionality with clearer naming

  2. Security
    - Maintain security definer settings
    - Keep proper RLS policies
*/

-- Drop existing functions to clean up
DROP FUNCTION IF EXISTS get_conversation_unread_count(uuid);
DROP FUNCTION IF EXISTS get_conversation_unread_count(uuid, boolean);

-- Create a single, clear function for unread counts
CREATE OR REPLACE FUNCTION get_conversation_unread_messages_count(
  p_conversation_id uuid,
  p_count_for_agency boolean
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
  WHERE m.conversation_id = p_conversation_id
  AND m.read_at IS NULL
  AND (
    (p_count_for_agency AND m.sender_type != 'agency' AND (auth.jwt() ->> 'role' = 'agency' OR c.agency_id = auth.uid()))
    OR
    (NOT p_count_for_agency AND m.sender_type = 'agency' AND c.user_id = auth.uid())
  );
  
  RETURN v_count;
END;
$$;

-- Update the get_conversations_with_status function to use the new unread count function
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
      get_conversation_unread_messages_count(c.id, true) as unread_count,
      COALESCE(get_conversation_unread_messages_count(c.id, true) = 0, true) as is_read
    FROM chat_conversations c
    LEFT JOIN auth.users u ON c.user_id = u.id
    WHERE c.status = 'active'
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
      get_conversation_unread_messages_count(c.id, false) as unread_count,
      COALESCE(get_conversation_unread_messages_count(c.id, false) = 0, true) as is_read
    FROM chat_conversations c
    LEFT JOIN auth.users u ON c.user_id = u.id
    WHERE c.status = 'active'
    AND c.user_id = auth.uid()
    ORDER BY c.last_message_at DESC NULLS LAST;
  END IF;
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_conversations_with_status() TO authenticated;
GRANT EXECUTE ON FUNCTION get_conversation_unread_messages_count(uuid, boolean) TO authenticated;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_read
ON chat_messages(conversation_id, read_at, sender_type)
WHERE read_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_conversations_last_message
ON chat_conversations(last_message_at DESC NULLS LAST);