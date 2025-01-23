-- Create function to get users with profiles
CREATE OR REPLACE FUNCTION get_users_with_profiles()
RETURNS TABLE (
  id uuid,
  email text,
  raw_user_meta_data jsonb,
  created_at timestamptz,
  updated_at timestamptz,
  profile jsonb
) 
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
BEGIN
  IF (SELECT auth.jwt() ->> 'role') = 'agency' THEN
    RETURN QUERY 
    SELECT 
      u.id,
      u.email::text,
      u.raw_user_meta_data,
      u.created_at,
      u.updated_at,
      to_jsonb(up.*) - 'id' - 'user_id' - 'created_at' - 'updated_at' as profile
    FROM auth.users u
    LEFT JOIN user_profiles up ON up.user_id = u.id
    WHERE (u.status IS NULL OR u.status = 'active')
    ORDER BY u.email;
  ELSE
    RETURN QUERY 
    SELECT 
      u.id,
      u.email::text,
      u.raw_user_meta_data,
      u.created_at,
      u.updated_at,
      to_jsonb(up.*) - 'id' - 'user_id' - 'created_at' - 'updated_at' as profile
    FROM auth.users u
    LEFT JOIN user_profiles up ON up.user_id = u.id
    WHERE u.id = auth.uid();
  END IF;
END;
$$;

-- Create function to get chat conversations with profiles
CREATE OR REPLACE FUNCTION get_chat_conversations_with_profiles(
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
  user_first_name text,
  user_last_name text,
  agency_email text,
  unread_count bigint
) 
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
BEGIN
  IF (SELECT auth.jwt() ->> 'role') = 'agency' THEN
    RETURN QUERY 
    SELECT DISTINCT ON (c.user_id)
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
      up.first_name as user_first_name,
      up.last_name as user_last_name,
      a.email::text as agency_email,
      COUNT(m.id) FILTER (
        WHERE m.read_at IS NULL 
        AND m.sender_type != 'agency'
      )::bigint as unread_count
    FROM chat_conversations c
    LEFT JOIN auth.users u ON c.user_id = u.id
    LEFT JOIN user_profiles up ON up.user_id = c.user_id
    LEFT JOIN auth.users a ON c.agency_id = a.id
    LEFT JOIN chat_messages m ON m.conversation_id = c.id
    WHERE c.status = p_status
    GROUP BY 
      c.id, c.user_id, c.agency_id, c.status, 
      c.last_message, c.last_message_at, c.is_bot_active,
      c.created_at, c.updated_at,
      u.email, up.first_name, up.last_name, a.email
    ORDER BY c.user_id, c.updated_at DESC;
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
      up.first_name as user_first_name,
      up.last_name as user_last_name,
      a.email::text as agency_email,
      COUNT(m.id) FILTER (
        WHERE m.read_at IS NULL 
        AND m.sender_type = 'agency'
      )::bigint as unread_count
    FROM chat_conversations c
    LEFT JOIN auth.users u ON c.user_id = u.id
    LEFT JOIN user_profiles up ON up.user_id = c.user_id
    LEFT JOIN auth.users a ON c.agency_id = a.id
    LEFT JOIN chat_messages m ON m.conversation_id = c.id
    WHERE c.user_id = auth.uid()
    AND c.status = p_status
    GROUP BY 
      c.id, c.user_id, c.agency_id, c.status, 
      c.last_message, c.last_message_at, c.is_bot_active,
      c.created_at, c.updated_at,
      u.email, up.first_name, up.last_name, a.email
    ORDER BY c.updated_at DESC;
  END IF;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_users_with_profiles() TO authenticated;
GRANT EXECUTE ON FUNCTION get_chat_conversations_with_profiles(text) TO authenticated;