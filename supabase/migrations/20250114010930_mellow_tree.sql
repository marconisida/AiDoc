/*
  # Update chat conversations function
  
  1. Changes
    - Update get_chat_conversations to use correct function name
    - Maintain existing functionality with updated function calls
*/

-- Update the get_chat_conversations function to use the new unread count function name
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
      get_conversation_unread_messages_count(c.id, true)::integer as unread_count
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
      get_conversation_unread_messages_count(c.id, false)::integer as unread_count
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