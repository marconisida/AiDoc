/*
  # Add Profile Fields for Document Requirements

  1. New Fields
    - nationality_country
    - desired_residency_type
    - birth_country
    - primary_residency_country
    - residency_goal
    - marital_status (updated)

  2. Changes
    - Add new columns to user_profiles table
    - Add validation for country fields
    - Add validation for residency type and goal
*/

-- Add new columns to user_profiles
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS nationality_country text,
ADD COLUMN IF NOT EXISTS desired_residency_type text,
ADD COLUMN IF NOT EXISTS birth_country text,
ADD COLUMN IF NOT EXISTS primary_residency_country text,
ADD COLUMN IF NOT EXISTS residency_goal text,
ADD COLUMN IF NOT EXISTS marital_status text;

-- Create type for residency types
DO $$ BEGIN
  CREATE TYPE residency_type AS ENUM (
    'temporary_short',
    'temporary_long',
    'permanent_investment'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create type for residency goals
DO $$ BEGIN
  CREATE TYPE residency_goal_type AS ENUM (
    'tax_residency',
    'plan_b',
    'relocation'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create type for marital status
DO $$ BEGIN
  CREATE TYPE marital_status_type AS ENUM (
    'single',
    'married',
    'divorced',
    'widowed'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Add constraints
ALTER TABLE user_profiles
  ADD CONSTRAINT valid_residency_type 
    CHECK (desired_residency_type::residency_type IN ('temporary_short', 'temporary_long', 'permanent_investment')),
  ADD CONSTRAINT valid_residency_goal 
    CHECK (residency_goal::residency_goal_type IN ('tax_residency', 'plan_b', 'relocation')),
  ADD CONSTRAINT valid_marital_status 
    CHECK (marital_status::marital_status_type IN ('single', 'married', 'divorced', 'widowed'));

-- Update the update_user_profile function to include new fields
CREATE OR REPLACE FUNCTION update_user_profile(
  p_user_id uuid,
  p_first_name text,
  p_last_name text,
  p_country text,
  p_preferred_language text,
  p_whatsapp text,
  p_birth_date text,
  p_shipping_address jsonb,
  p_nationality_country text DEFAULT NULL,
  p_desired_residency_type text DEFAULT NULL,
  p_birth_country text DEFAULT NULL,
  p_primary_residency_country text DEFAULT NULL,
  p_residency_goal text DEFAULT NULL,
  p_marital_status text DEFAULT NULL
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