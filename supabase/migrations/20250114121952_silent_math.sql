-- Create a function to ensure user progress is initialized
CREATE OR REPLACE FUNCTION ensure_user_progress(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_progress_id uuid;
  v_steps RECORD;
BEGIN
  -- Check if progress already exists
  SELECT id INTO v_progress_id
  FROM residency_progress
  WHERE user_id = p_user_id;

  -- If no progress exists, create it
  IF v_progress_id IS NULL THEN
    INSERT INTO residency_progress (user_id, current_step, status)
    VALUES (p_user_id, 1, 'active')
    RETURNING id INTO v_progress_id;

    -- Insert step progress for each residency step
    FOR v_steps IN (
      SELECT id FROM residency_steps ORDER BY order_number
    ) LOOP
      INSERT INTO residency_step_progress (
        progress_id,
        step_id,
        status
      ) VALUES (
        v_progress_id,
        v_steps.id,
        'pending'
      );
    END LOOP;
  END IF;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION ensure_user_progress TO authenticated;

-- Create a trigger to automatically initialize progress for new users
CREATE OR REPLACE FUNCTION initialize_user_progress()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM ensure_user_progress(NEW.id);
  RETURN NEW;
END;
$$;

-- Create the trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION initialize_user_progress();

-- Initialize progress for any existing users without progress
DO $$
DECLARE
  v_user RECORD;
BEGIN
  FOR v_user IN (
    SELECT id FROM auth.users u
    WHERE NOT EXISTS (
      SELECT 1 FROM residency_progress rp
      WHERE rp.user_id = u.id
    )
  ) LOOP
    PERFORM ensure_user_progress(v_user.id);
  END LOOP;
END $$;