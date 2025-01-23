-- Add email_confirmed field to user metadata if it doesn't exist
CREATE OR REPLACE FUNCTION ensure_user_metadata()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Initialize raw_user_meta_data if null
  IF NEW.raw_user_meta_data IS NULL THEN
    NEW.raw_user_meta_data = '{}'::jsonb;
  END IF;

  -- Add email_confirmed if it doesn't exist
  IF NOT (NEW.raw_user_meta_data ? 'email_confirmed') THEN
    NEW.raw_user_meta_data = NEW.raw_user_meta_data || 
      '{"email_confirmed": false}'::jsonb;
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger for new users
DROP TRIGGER IF EXISTS ensure_user_metadata_trigger ON auth.users;
CREATE TRIGGER ensure_user_metadata_trigger
  BEFORE INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION ensure_user_metadata();

-- Update existing users
UPDATE auth.users
SET raw_user_meta_data = raw_user_meta_data || 
  '{"email_confirmed": false}'::jsonb
WHERE NOT (raw_user_meta_data ? 'email_confirmed');

-- Ensure progress initialization happens after metadata is set
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION initialize_user_progress();