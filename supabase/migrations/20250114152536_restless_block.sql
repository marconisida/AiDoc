-- Create a secure function to update user profile
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

  -- Update the profile
  UPDATE user_profiles
  SET
    first_name = p_first_name,
    last_name = p_last_name,
    country = p_country,
    preferred_language = p_preferred_language,
    whatsapp = p_whatsapp,
    birth_date = p_birth_date,
    shipping_address = p_shipping_address,
    updated_at = now()
  WHERE user_id = p_user_id
  RETURNING * INTO v_profile;

  RETURN v_profile;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_user_profile TO authenticated;