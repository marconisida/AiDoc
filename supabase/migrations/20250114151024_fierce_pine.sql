/*
  # Add User Profiles

  1. New Tables
    - `user_profiles`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `first_name` (text)
      - `last_name` (text)
      - `country` (text)
      - `preferred_language` (text)
      - `whatsapp` (text)
      - `birth_date` (date)
      - `shipping_address` (jsonb)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `user_profiles`
    - Add policies for users and agency access
    - Add function to get user profile with security checks

  3. Changes
    - Add trigger to create profile on user creation
    - Add function to update profile
*/

-- Create user_profiles table
CREATE TABLE IF NOT EXISTS user_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name text,
  last_name text,
  country text,
  preferred_language text,
  whatsapp text,
  birth_date date,
  shipping_address jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view own profile"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id OR 
    auth.jwt() ->> 'role' = 'agency'
  );

CREATE POLICY "Users can update own profile"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = user_id OR 
    auth.jwt() ->> 'role' = 'agency'
  )
  WITH CHECK (
    auth.uid() = user_id OR 
    auth.jwt() ->> 'role' = 'agency'
  );

-- Create function to get user profile
CREATE OR REPLACE FUNCTION get_user_profile(p_user_id uuid)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  first_name text,
  last_name text,
  country text,
  preferred_language text,
  whatsapp text,
  birth_date date,
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
      up.*,
      u.email::text
    FROM user_profiles up
    JOIN auth.users u ON u.id = up.user_id
    WHERE up.user_id = p_user_id;
  END IF;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_user_profile TO authenticated;

-- Create trigger function to update timestamp
CREATE OR REPLACE FUNCTION update_profile_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER update_profile_timestamp
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_profile_timestamp();

-- Modify initialize_new_user function to create profile
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

  -- Create user profile
  INSERT INTO user_profiles (user_id)
  VALUES (NEW.id);

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
    RAISE WARNING 'Error initializing user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

-- Create profiles for existing users
INSERT INTO user_profiles (user_id)
SELECT id FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM user_profiles up
  WHERE up.user_id = u.id
);