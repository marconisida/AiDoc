-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS get_user_profile(uuid);
DROP FUNCTION IF EXISTS update_user_profile(uuid, text, text, text, text, text, text, jsonb);

-- Create or update the table
CREATE TABLE IF NOT EXISTS user_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name text,
  last_name text,
  country text,
  preferred_language text,
  whatsapp text,
  birth_date text,
  shipping_address jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Create single comprehensive policy
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Users can manage own profile" ON user_profiles;
  CREATE POLICY "Users can manage own profile"
    ON user_profiles
    FOR ALL
    TO authenticated
    USING (
      auth.uid() = user_id OR 
      auth.jwt() ->> 'role' = 'agency'
    )
    WITH CHECK (
      auth.uid() = user_id OR 
      auth.jwt() ->> 'role' = 'agency'
    );
END $$;

-- Create function to get user profile with proper types
CREATE OR REPLACE FUNCTION get_user_profile(p_user_id uuid)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  first_name text,
  last_name text,
  country text,
  preferred_language text,
  whatsapp text,
  birth_date text,
  shipping_address jsonb,
  email text,
  created_at timestamptz,
  updated_at timestamptz
) 
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
BEGIN
  IF (auth.uid() = p_user_id) OR (SELECT auth.jwt() ->> 'role') = 'agency' THEN
    RETURN QUERY 
    SELECT 
      up.id,
      up.user_id,
      up.first_name,
      up.last_name,
      up.country,
      up.preferred_language,
      up.whatsapp,
      up.birth_date,
      up.shipping_address,
      u.email::text,
      up.created_at,
      up.updated_at
    FROM user_profiles up
    JOIN auth.users u ON u.id = up.user_id
    WHERE up.user_id = p_user_id;
  END IF;
END;
$$;

-- Create function to update user profile
CREATE OR REPLACE FUNCTION update_user_profile(
  p_user_id uuid,
  p_first_name text,
  p_last_name text,
  p_country text,
  p_preferred_language text,
  p_whatsapp text,
  p_birth_date text,
  p_shipping_address jsonb
)
RETURNS user_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_profile user_profiles;
BEGIN
  -- Check if user has permission
  IF NOT (auth.uid() = p_user_id OR (SELECT auth.jwt() ->> 'role') = 'agency') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Update or insert the profile
  INSERT INTO user_profiles (
    user_id,
    first_name,
    last_name,
    country,
    preferred_language,
    whatsapp,
    birth_date,
    shipping_address
  )
  VALUES (
    p_user_id,
    p_first_name,
    p_last_name,
    p_country,
    p_preferred_language,
    p_whatsapp,
    p_birth_date,
    p_shipping_address
  )
  ON CONFLICT (user_id) DO UPDATE
  SET
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    country = EXCLUDED.country,
    preferred_language = EXCLUDED.preferred_language,
    whatsapp = EXCLUDED.whatsapp,
    birth_date = EXCLUDED.birth_date,
    shipping_address = EXCLUDED.shipping_address,
    updated_at = now()
  RETURNING * INTO v_profile;

  RETURN v_profile;
END;
$$;

-- Create trigger function for timestamp updates
CREATE OR REPLACE FUNCTION update_profile_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS update_profile_timestamp ON user_profiles;
CREATE TRIGGER update_profile_timestamp
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_profile_timestamp();

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_user_profile TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_profile TO authenticated;

-- Create profiles for existing users
INSERT INTO user_profiles (user_id)
SELECT id FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM user_profiles up
  WHERE up.user_id = u.id
)
AND (u.status IS NULL OR u.status = 'active');