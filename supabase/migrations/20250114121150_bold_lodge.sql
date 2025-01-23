-- Create a type for hide confirmation status
CREATE TYPE hide_confirmation_status AS ENUM ('pending', 'confirmed', 'rejected');

-- Add confirmation requirement to hide_user function
DO $$ 
BEGIN
  CREATE OR REPLACE FUNCTION hide_user(
    user_id uuid,
    confirmation_phrase text
  )
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public, auth
  AS $func$
  DECLARE
    v_user_exists boolean;
    v_expected_phrase text := 'CONFIRMO OCULTAR USUARIO';
  BEGIN
    -- Check if the requesting user is an agency
    IF (SELECT auth.jwt() ->> 'role') != 'agency' THEN
      RAISE EXCEPTION 'Only agency users can hide users';
    END IF;

    -- Verify confirmation phrase
    IF confirmation_phrase IS NULL OR confirmation_phrase != v_expected_phrase THEN
      RAISE EXCEPTION 'Invalid confirmation phrase. Please type "CONFIRMO OCULTAR USUARIO" to proceed.';
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
    RAISE NOTICE 'User % successfully hidden with confirmation', user_id;
  END;
  $func$;
END $$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION hide_user(uuid, text) TO authenticated;