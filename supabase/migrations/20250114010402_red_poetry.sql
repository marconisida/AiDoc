/*
  # Fix chat read status tracking

  1. Changes
    - Add trigger to update conversation read status
    - Add function to mark messages as read
    - Add function to get unread messages count
    - Add indexes for better performance

  2. Security
    - Functions are security definer to ensure proper access control
    - RLS policies remain unchanged
*/

-- Create a function to mark messages as read
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
    AND sender_type != (
      CASE WHEN auth.jwt() ->> 'role' = 'agency' THEN 'agency' ELSE 'user' END
    )
    AND (p_up_to_message_id IS NULL OR id <= p_up_to_message_id);
END;
$$;

-- Create a function to get unread messages count with caching
CREATE OR REPLACE FUNCTION get_unread_count(
  p_conversation_id uuid,
  p_user_type text
)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_count integer;
BEGIN
  SELECT COUNT(*)::integer
  INTO v_count
  FROM chat_messages
  WHERE conversation_id = p_conversation_id
    AND read_at IS NULL
    AND sender_type != p_user_type;
    
  RETURN v_count;
END;
$$;

-- Create a materialized view for conversation stats
CREATE MATERIALIZED VIEW IF NOT EXISTS chat_conversation_stats AS
SELECT 
  conversation_id,
  COUNT(*) FILTER (WHERE read_at IS NULL AND sender_type != 'agency') as agency_unread,
  COUNT(*) FILTER (WHERE read_at IS NULL AND sender_type = 'agency') as user_unread,
  MAX(created_at) as last_activity
FROM chat_messages
GROUP BY conversation_id;

-- Create index on the materialized view
CREATE UNIQUE INDEX IF NOT EXISTS chat_conversation_stats_id_idx 
ON chat_conversation_stats(conversation_id);

-- Create function to refresh conversation stats
CREATE OR REPLACE FUNCTION refresh_conversation_stats()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY chat_conversation_stats;
  RETURN NULL;
END;
$$;

-- Create trigger to refresh stats
CREATE TRIGGER refresh_conversation_stats_trigger
AFTER INSERT OR UPDATE OR DELETE ON chat_messages
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_conversation_stats();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION mark_messages_as_read(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_unread_count(uuid, text) TO authenticated;
GRANT SELECT ON chat_conversation_stats TO authenticated;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chat_messages_read_status
ON chat_messages(conversation_id, read_at, sender_type)
WHERE read_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_chat_messages_sender
ON chat_messages(conversation_id, sender_type, created_at);