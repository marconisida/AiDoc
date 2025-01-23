-- Function to ensure residency progress exists for a user
CREATE OR REPLACE FUNCTION ensure_residency_progress(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_progress_id uuid;
  v_steps RECORD;
BEGIN
  -- Check if progress already exists using parameter name
  SELECT rp.id INTO v_progress_id
  FROM residency_progress rp
  WHERE rp.user_id = p_user_id;

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

-- Initialize progress for all existing users
DO $$
DECLARE
  v_user RECORD;
BEGIN
  FOR v_user IN (
    SELECT id FROM auth.users 
    WHERE status IS NULL OR status = 'active'
  ) LOOP
    PERFORM ensure_residency_progress(v_user.id);
  END LOOP;
END $$;

-- Create trigger to automatically initialize progress for new users
CREATE OR REPLACE FUNCTION initialize_user_progress()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM ensure_residency_progress(NEW.id);
  RETURN NEW;
END;
$$;

-- Create the trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION initialize_user_progress();

-- Ensure all necessary indexes exist
CREATE INDEX IF NOT EXISTS idx_residency_progress_user_id
  ON residency_progress(user_id);

CREATE INDEX IF NOT EXISTS idx_residency_step_progress_progress_id
  ON residency_step_progress(progress_id);

CREATE INDEX IF NOT EXISTS idx_residency_step_progress_step_id
  ON residency_step_progress(step_id);

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION ensure_residency_progress TO authenticated;
GRANT EXECUTE ON FUNCTION initialize_user_progress TO authenticated;