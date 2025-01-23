/*
  # Add Agency User

  1. Changes
    - Create agency user with email and password
    - Set agency role in user metadata
    - Add agency role to JWT claims

  2. Security
    - Password is hashed by Supabase Auth
    - Role is secured through RLS policies
*/

-- Create the agency user
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'agency@example.com',
  crypt('agency123', gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}',
  '{"role":"agency"}',
  now(),
  now(),
  '',
  '',
  '',
  ''
);

-- Update JWT claims to include role
CREATE OR REPLACE FUNCTION auth.jwt()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = auth, pg_catalog, public
AS $$
  SELECT
    coalesce(
      nullif(current_setting('request.jwt.claim', true), ''),
      nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
    || jsonb_build_object(
      'role',
      (SELECT (raw_user_meta_data->>'role')::text FROM auth.users WHERE id = auth.uid())
    )
$$;