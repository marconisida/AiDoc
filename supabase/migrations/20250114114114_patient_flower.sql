/*
  # Add secure user deletion function
  
  1. New Functions
    - delete_user: Securely deletes a user and their data
  
  2. Security
    - Only agency users can delete users
    - Cascading deletion of all user data
*/

-- Create a secure function to delete users
CREATE OR REPLACE FUNCTION delete_user(user_id uuid)
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
  DELETE FROM residency_progress WHERE user_id = user_id;
  DELETE FROM documents WHERE user_id = user_id;
  DELETE FROM chat_conversations WHERE user_id = user_id;
  
  -- Delete user from auth schema
  DELETE FROM auth.users WHERE id = user_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user TO authenticated;