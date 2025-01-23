-- Drop existing triggers to avoid conflicts
DROP TRIGGER IF EXISTS ensure_user_metadata_trigger ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create a combined function to handle both metadata and progress
CREATE OR REPLACE FUNCTION initialize_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_progress_id uuid;
  v_steps RECORD;
BEGIN
  -- Initialize metadata
  IF NEW.raw_user_meta_data IS NULL THEN
    NEW.raw_user_meta_data = '{}'::jsonb;
  END IF;

  -- Add email_confirmed if it doesn't exist
  IF NOT (NEW.raw_user_meta_data ? 'email_confirmed') THEN
    NEW.raw_user_meta_data = NEW.raw_user_meta_data || 
      '{"email_confirmed": false}'::jsonb;
  END IF;

  -- Create progress entry
  INSERT INTO residency_progress (user_id, current_step, status)
  VALUES (NEW.id, 1, 'active')
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

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't prevent user creation
    RAISE WARNING 'Error initializing user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

-- Create a single trigger that handles everything
CREATE TRIGGER initialize_new_user_trigger
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION initialize_new_user();

-- Update existing users that might be missing metadata
UPDATE auth.users
SET raw_user_meta_data = raw_user_meta_data || 
  '{"email_confirmed": false}'::jsonb
WHERE NOT (raw_user_meta_data ? 'email_confirmed');

-- Ensure all existing users have progress
DO $$
DECLARE
  v_user RECORD;
  v_progress_id uuid;
  v_steps RECORD;
BEGIN
  FOR v_user IN (
    SELECT id FROM auth.users u
    WHERE NOT EXISTS (
      SELECT 1 FROM residency_progress rp
      WHERE rp.user_id = u.id
    )
  ) LOOP
    -- Create progress for user
    INSERT INTO residency_progress (user_id, current_step, status)
    VALUES (v_user.id, 1, 'active')
    RETURNING id INTO v_progress_id;

    -- Create step progress
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
  END LOOP;
END $$;