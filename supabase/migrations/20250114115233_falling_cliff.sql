-- Drop existing function
DROP FUNCTION IF EXISTS delete_user(uuid);

-- Create improved delete_user function
CREATE OR REPLACE FUNCTION delete_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_exists boolean;
BEGIN
  -- Check if the requesting user is an agency
  IF (SELECT auth.jwt() ->> 'role') != 'agency' THEN
    RAISE EXCEPTION 'Only agency users can delete users';
  END IF;

  -- Check if user exists
  SELECT EXISTS (
    SELECT 1 FROM auth.users WHERE id = p_user_id
  ) INTO v_user_exists;

  IF NOT v_user_exists THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  -- Delete in a specific order to handle dependencies
  DELETE FROM chat_participants WHERE user_id = p_user_id;
  DELETE FROM chat_messages WHERE sender_id = p_user_id;
  DELETE FROM chat_conversations WHERE user_id = p_user_id;
  DELETE FROM residency_step_progress 
    WHERE progress_id IN (
      SELECT id FROM residency_progress WHERE user_id = p_user_id
    );
  DELETE FROM residency_progress WHERE user_id = p_user_id;
  DELETE FROM documents WHERE user_id = p_user_id;
  
  -- Finally delete the user
  DELETE FROM auth.users WHERE id = p_user_id;

  -- Raise notice for logging
  RAISE NOTICE 'User % successfully deleted', p_user_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user TO authenticated;