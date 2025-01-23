-- Drop existing function if it exists
DROP FUNCTION IF EXISTS public.get_users();

-- Create a secure function to access auth.users with correct types
CREATE OR REPLACE FUNCTION public.get_users()
RETURNS TABLE (
  id uuid,
  email text,
  raw_user_meta_data jsonb,
  created_at timestamptz,
  updated_at timestamptz
) 
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
BEGIN
  IF (SELECT auth.jwt() ->> 'role') = 'agency' THEN
    RETURN QUERY SELECT 
      au.id,
      au.email::text,
      au.raw_user_meta_data,
      au.created_at,
      au.updated_at
    FROM auth.users au;
  ELSE
    RETURN QUERY SELECT 
      au.id,
      au.email::text,
      au.raw_user_meta_data,
      au.created_at,
      au.updated_at
    FROM auth.users au
    WHERE au.id = auth.uid();
  END IF;
END;
$$;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION public.get_users TO authenticated;