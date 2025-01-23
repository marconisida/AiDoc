-- Drop existing functions to avoid conflicts
DROP FUNCTION IF EXISTS update_user_profile(uuid, text, text, text, text, text, text, jsonb);
DROP FUNCTION IF EXISTS update_user_profile(uuid, text, text, text, text, text, text, jsonb, text, text, text, text, text, text);
DROP FUNCTION IF EXISTS update_user_profile(uuid, text, text, text, text, text, text, jsonb, text, text, text, text, text, text, text, text, text);

-- Create updated function with unique name
CREATE OR REPLACE FUNCTION update_user_profile_v2(
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
  p_marital_status text,
  p_internal_agency_notes text DEFAULT NULL,
  p_client_to_agency_notes text DEFAULT NULL,
  p_agency_to_client_notes text DEFAULT NULL
)
RETURNS user_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_profile user_profiles;
  v_is_agency boolean;
BEGIN
  -- Check if user has permission
  IF NOT (auth.uid() = p_user_id OR (SELECT auth.jwt() ->> 'role') = 'agency') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Check if user is agency
  v_is_agency := (SELECT auth.jwt() ->> 'role') = 'agency';

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
    marital_status,
    internal_agency_notes,
    client_to_agency_notes,
    agency_to_client_notes
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
    p_marital_status,
    CASE WHEN v_is_agency THEN p_internal_agency_notes ELSE NULL END,
    p_client_to_agency_notes,
    CASE WHEN v_is_agency THEN p_agency_to_client_notes ELSE NULL END
  )
  ON CONFLICT (user_id) DO UPDATE
  SET
    first_name = p_first_name,
    last_name = p_last_name,
    country = p_country,
    preferred_language = p_preferred_language,
    whatsapp = p_whatsapp,
    birth_date = p_birth_date,
    shipping_address = p_shipping_address,
    nationality_country = p_nationality_country,
    desired_residency_type = p_desired_residency_type,
    birth_country = p_birth_country,
    primary_residency_country = p_primary_residency_country,
    residency_goal = p_residency_goal,
    marital_status = p_marital_status,
    internal_agency_notes = CASE 
      WHEN v_is_agency THEN p_internal_agency_notes 
      ELSE user_profiles.internal_agency_notes 
    END,
    client_to_agency_notes = p_client_to_agency_notes,
    agency_to_client_notes = CASE 
      WHEN v_is_agency THEN p_agency_to_client_notes 
      ELSE user_profiles.agency_to_client_notes 
    END,
    updated_at = now()
  RETURNING * INTO v_profile;

  RETURN v_profile;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_user_profile_v2 TO authenticated;