/*
  # Fix Agency Schema and User Management

  1. Changes
    - Create function to access auth.users safely
    - Add secure way to query users
    - Update residency progress queries

  2. Security
    - Implement secure access to user data
    - Maintain RLS security
*/

-- Create a secure function to access auth.users
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
      au.email,
      au.raw_user_meta_data,
      au.created_at,
      au.updated_at
    FROM auth.users au;
  ELSE
    RETURN QUERY SELECT 
      au.id,
      au.email,
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

-- Create a secure function to get a specific user
CREATE OR REPLACE FUNCTION public.get_user(user_id uuid)
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
  IF (auth.uid() = user_id) OR (SELECT auth.jwt() ->> 'role') = 'agency' THEN
    RETURN QUERY SELECT 
      au.id,
      au.email,
      au.raw_user_meta_data,
      au.created_at,
      au.updated_at
    FROM auth.users au
    WHERE au.id = user_id;
  END IF;
END;
$$;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION public.get_user TO authenticated;