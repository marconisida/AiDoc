-- Drop existing function first
DROP FUNCTION IF EXISTS delete_user(uuid);

-- Create a secure function to delete users
CREATE OR REPLACE FUNCTION delete_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  -- Check if the requesting user is an agency
  IF (SELECT auth.jwt() ->> 'role') != 'agency' THEN
    RAISE EXCEPTION 'Only agency users can delete users';
  END IF;

  -- Delete user data from public schema tables
  DELETE FROM residency_progress WHERE user_id = p_user_id;
  DELETE FROM documents WHERE user_id = p_user_id;
  DELETE FROM chat_conversations WHERE user_id = p_user_id;
  
  -- Delete user from auth schema
  DELETE FROM auth.users WHERE id = p_user_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user TO authenticated;