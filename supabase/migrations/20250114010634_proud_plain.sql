/*
  # Fix conversation list display and read status

  1. Changes
    - Add function to get conversations with proper read status
    - Create materialized view for conversation stats
    - Add indexes for better performance

  2. Security
    - Functions are security definer to ensure proper access control
    - RLS policies remain unchanged
*/

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS refresh_conversation_stats_trigger ON chat_messages;

-- Create a function to get conversations with read status
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
END;
$$;

-- Create materialized view for conversation stats
CREATE MATERIALIZED VIEW IF NOT EXISTS conversation_stats AS
SELECT 
  c.id as conversation_id,
  c.user_id,
  u.email as user_email,
  c.last_message,
  c.last_message_at,
  COUNT(m.id) FILTER (WHERE m.read_at IS NULL AND m.sender_type != 'agency') as unread_count,
  COALESCE(bool_and(m.read_at IS NOT NULL OR m.sender_type = 'agency'), true) as is_read
FROM chat_conversations c
LEFT JOIN auth.users u ON c.user_id = u.id
LEFT JOIN chat_messages m ON c.id = m.conversation_id
WHERE c.status = 'active'
GROUP BY c.id, c.user_id, u.email, c.last_message, c.last_message_at;

-- Create unique index on the materialized view
CREATE UNIQUE INDEX IF NOT EXISTS conversation_stats_id_idx 
ON conversation_stats(conversation_id);

-- Create function to refresh conversation stats
CREATE OR REPLACE FUNCTION refresh_conversation_stats()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY conversation_stats;
  RETURN NULL;
END;
$$;

-- Create trigger for stats refresh
CREATE TRIGGER refresh_conversation_stats_trigger
AFTER INSERT OR UPDATE OR DELETE ON chat_messages
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_conversation_stats();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_conversations_with_status() TO authenticated;
GRANT SELECT ON conversation_stats TO authenticated;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_read
ON chat_messages(conversation_id, read_at, sender_type)
WHERE read_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_conversations_last_message
ON chat_conversations(last_message_at DESC NULLS LAST);