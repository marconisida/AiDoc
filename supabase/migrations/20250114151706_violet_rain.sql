/*
  # User Profile Schema Update

  1. Changes
    - Modify user_profiles table to use text for birth_date
    - Update get_user_profile function with proper types
    - Add proper RLS policies with safe policy creation
  
  2. Security
    - Enable RLS on user_profiles table
    - Add policies for user and agency access
    - Secure function with proper permissions
*/

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_user_profile(uuid);

-- Create user_profiles table with proper types
DO $$ 
BEGIN
  -- Safely drop existing policies
  DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
  DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
  DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
END $$;

-- Create or update the table
CREATE TABLE IF NOT EXISTS user_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name text,
  last_name text,
  country text,
  preferred_language text,
  whatsapp text,
  birth_date text, -- Store as text for better compatibility
  shipping_address jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Create new policies
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
DROP TRIGGER IF EXISTS update_profile_timestamp ON user_profiles;
CREATE TRIGGER update_profile_timestamp
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_profile_timestamp();

-- Create profiles for existing users
INSERT INTO user_profiles (user_id)
SELECT id FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM user_profiles up
  WHERE up.user_id = u.id
)
AND (u.status IS NULL OR u.status = 'active');