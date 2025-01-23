-- Add status field to track user visibility
ALTER TABLE auth.users 
ADD COLUMN IF NOT EXISTS status text DEFAULT 'active';

-- Create function to hide users instead of deleting them
DO $$ 
BEGIN
  CREATE OR REPLACE FUNCTION hide_user(user_id uuid)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public, auth
  AS $func$
  DECLARE
    v_user_exists boolean;
  BEGIN
    -- Check if the requesting user is an agency
    IF (SELECT auth.jwt() ->> 'role') != 'agency' THEN
      RAISE EXCEPTION 'Only agency users can hide users';
    END IF;

    -- Check if user exists
    SELECT EXISTS (
      SELECT 1 FROM auth.users WHERE id = user_id
    ) INTO v_user_exists;

    IF NOT v_user_exists THEN
      RAISE EXCEPTION 'User not found';
    END IF;

    -- Update user status to hidden
    UPDATE auth.users 
    SET status = 'hidden'
    WHERE id = user_id;

    -- Raise notice for logging
    RAISE NOTICE 'User % successfully hidden', user_id;
  END;
  $func$;
END $$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION hide_user(uuid) TO authenticated;

-- Update the get_users function to only return active users
DO $$ 
BEGIN
  CREATE OR REPLACE FUNCTION get_users()
  RETURNS TABLE (
    id uuid,
    email text,
    raw_user_meta_data jsonb,
    created_at timestamptz,
    updated_at timestamptz
  ) 
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public, auth
  AS $func$
  BEGIN
    IF (SELECT auth.jwt() ->> 'role') = 'agency' THEN
      RETURN QUERY SELECT 
        au.id,
        au.email::text,
        au.raw_user_meta_data,
        au.created_at,
        au.updated_at
      FROM auth.users au
      WHERE (au.status IS NULL OR au.status = 'active');
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
  $func$;
END $$;