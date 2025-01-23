-- Add new columns to user_profiles if they don't exist
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS nationality_country text,
ADD COLUMN IF NOT EXISTS desired_residency_type text,
ADD COLUMN IF NOT EXISTS birth_country text,
ADD COLUMN IF NOT EXISTS primary_residency_country text,
ADD COLUMN IF NOT EXISTS residency_goal text,
ADD COLUMN IF NOT EXISTS marital_status text;

-- Drop all existing functions first to avoid conflicts
DROP FUNCTION IF EXISTS get_user_profile(uuid);
DROP FUNCTION IF EXISTS update_user_profile(uuid, text, text, text, text, text, text, jsonb);
DROP FUNCTION IF EXISTS update_user_profile(uuid, text, text, text, text, text, text, jsonb, text, text, text, text, text, text);

-- Create function to get user profile with new fields
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
  nationality_country text,
  desired_residency_type text,
  birth_country text,
  primary_residency_country text,
  residency_goal text,
  marital_status text,
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
      up.nationality_country,
      up.desired_residency_type,
      up.birth_country,
      up.primary_residency_country,
      up.residency_goal,
      up.marital_status,
      u.email::text,
      up.created_at,
      up.updated_at
    FROM user_profiles up
    JOIN auth.users u ON u.id = up.user_id
    WHERE up.user_id = p_user_id;
  END IF;
END;
$$;

-- Create function to update user profile with new fields
CREATE OR REPLACE FUNCTION update_user_profile(
  p_user_id uuid,
  p_first_name text,
  p_last_name text,
  p_country text,
  p_preferred_language text,
  p_whatsapp text,
  p_birth_date text,
  p_shipping_address jsonb,
  p_nationality_country text,
  p_desired_residency_type text,
  p_birth_country text,
  p_primary_residency_country text,
  p_residency_goal text,
  p_marital_status text
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
    shipping_address,
    nationality_country,
    desired_residency_type,
    birth_country,
    primary_residency_country,
    residency_goal,
    marital_status
  )
  VALUES (
    p_user_id,
    p_first_name,
    p_last_name,
    p_country,
    p_preferred_language,
    p_whatsapp,
    p_birth_date,
    p_shipping_address,
    p_nationality_country,
    p_desired_residency_type,
    p_birth_country,
    p_primary_residency_country,
    p_residency_goal,
    p_marital_status
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
    nationality_country = EXCLUDED.nationality_country,
    desired_residency_type = EXCLUDED.desired_residency_type,
    birth_country = EXCLUDED.birth_country,
    primary_residency_country = EXCLUDED.primary_residency_country,
    residency_goal = EXCLUDED.residency_goal,
    marital_status = EXCLUDED.marital_status,
    updated_at = now()
  RETURNING * INTO v_profile;

  RETURN v_profile;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_user_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_profile(uuid, text, text, text, text, text, text, jsonb, text, text, text, text, text, text) TO authenticated;