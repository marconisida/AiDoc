-- Drop existing get_user function if it exists
DROP FUNCTION IF EXISTS get_user(uuid);

-- Create improved get_user function with correct types
CREATE OR REPLACE FUNCTION get_user(user_id uuid)
RETURNS TABLE (
  id uuid,
  email varchar,
  raw_user_meta_data jsonb,
  created_at timestamptz,
  updated_at timestamptz
) 
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
BEGIN
  IF (auth.uid() = user_id) OR (SELECT auth.jwt() ->> 'role') = 'agency' THEN
    RETURN QUERY SELECT 
      au.id,
      au.email,
      au.raw_user_meta_data,
      au.created_at,
      au.updated_at
    FROM auth.users au
    WHERE au.id = user_id
    AND (au.status IS NULL OR au.status = 'active');
  END IF;
END;
$$;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION get_user(uuid) TO authenticated;