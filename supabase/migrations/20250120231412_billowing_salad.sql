-- Drop existing functions and triggers first
DO $$ 
BEGIN
  -- Drop trigger first
  DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
  
  -- Drop functions
  DROP FUNCTION IF EXISTS initialize_user_progress();
  DROP FUNCTION IF EXISTS initialize_user_progress(uuid);
  DROP FUNCTION IF EXISTS ensure_residency_progress(uuid);
EXCEPTION
  WHEN undefined_function OR undefined_object THEN NULL;
END $$;

-- Create type for step status if it doesn't exist
DO $$ 
BEGIN
  CREATE TYPE step_status AS ENUM (
    'pending',
    'in_progress',
    'completed',
    'blocked'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create type for progress status if it doesn't exist
DO $$ 
BEGIN
  CREATE TYPE progress_status AS ENUM (
    'active',
    'completed',
    'blocked'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Ensure residency steps table exists
CREATE TABLE IF NOT EXISTS residency_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text NOT NULL,
  order_number integer NOT NULL,
  estimated_time text,
  requirements text[],
  created_at timestamptz DEFAULT now(),
  UNIQUE (order_number)
);

-- Ensure residency progress table exists
CREATE TABLE IF NOT EXISTS residency_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  current_step integer NOT NULL DEFAULT 1,
  status progress_status NOT NULL DEFAULT 'active',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (user_id)
);

-- Ensure residency step progress table exists
CREATE TABLE IF NOT EXISTS residency_step_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  progress_id uuid REFERENCES residency_progress(id) ON DELETE CASCADE,
  step_id uuid REFERENCES residency_steps(id) ON DELETE CASCADE,
  status step_status NOT NULL DEFAULT 'pending',
  notes text,
  completed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (progress_id, step_id)
);

-- Create function to initialize user progress
CREATE OR REPLACE FUNCTION ensure_residency_progress(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_progress_id uuid;
  v_step RECORD;
BEGIN
  -- Create progress entry if it doesn't exist
  INSERT INTO residency_progress (user_id, current_step, status)
  VALUES (p_user_id, 1, 'active')
  ON CONFLICT (user_id) DO NOTHING
  RETURNING id INTO v_progress_id;

  -- Get the progress_id if we didn't create one
  IF v_progress_id IS NULL THEN
    SELECT id INTO v_progress_id
    FROM residency_progress
    WHERE user_id = p_user_id;
  END IF;

  -- Create step progress entries
  FOR v_step IN (
    SELECT id FROM residency_steps ORDER BY order_number
  ) LOOP
    INSERT INTO residency_step_progress (progress_id, step_id, status)
    VALUES (v_progress_id, v_step.id, 'pending')
    ON CONFLICT (progress_id, step_id) DO NOTHING;
  END LOOP;
END;
$$;

-- Initialize steps if they don't exist
INSERT INTO residency_steps (title, description, order_number, estimated_time, requirements)
SELECT * FROM (VALUES
  (
    'Document Upload',
    'Initial submission and review of required documents in digital format',
    1,
    '1-2 business days',
    ARRAY['Scanned documents', 'Valid passport']
  ),
  (
    'Translation and Notarization',
    'Official translation to Spanish and notarization of foreign documents',
    2,
    '3-7 business days',
    ARRAY['Original documents', 'Translation fee payment']
  ),
  (
    'Immigration Appointment',
    'Physical document submission and interview at Immigration Office',
    3,
    '1 day',
    ARRAY['Original documents', 'Passport', 'Fee payment receipt']
  ),
  (
    'Residency Issuance',
    'Processing and follow-up of application at Immigration Office',
    4,
    '30-60 days',
    ARRAY['Complete file']
  ),
  (
    'ID Card Processing',
    'Processing of Paraguayan ID at the Identification Department',
    5,
    '7-10 business days',
    ARRAY['Residency card', 'Photos', 'Fingerprints']
  ),
  (
    'ID Card Reception',
    'Physical delivery of Paraguayan ID',
    6,
    '1-2 business days',
    ARRAY['Processing receipt']
  ),
  (
    'Tax ID Processing',
    'Registration with Treasury to obtain Tax ID',
    7,
    '3-5 business days',
    ARRAY['Paraguayan ID', 'Valid residency']
  ),
  (
    'Tax ID Reception',
    'Delivery of official Tax ID document and process completion',
    8,
    '1-2 business days',
    ARRAY['Complete documentation']
  )
) AS v (title, description, order_number, estimated_time, requirements)
WHERE NOT EXISTS (
  SELECT 1 FROM residency_steps
);

-- Initialize progress for existing users
DO $$
DECLARE
  v_user RECORD;
BEGIN
  FOR v_user IN (
    SELECT id FROM auth.users 
    WHERE status IS NULL OR status = 'active'
  ) LOOP
    PERFORM ensure_residency_progress(v_user.id);
  END LOOP;
END $$;

-- Create trigger function for new users
CREATE OR REPLACE FUNCTION on_auth_user_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM ensure_residency_progress(NEW.id);
  RETURN NEW;
END;
$$;

-- Create the trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION on_auth_user_created();

-- Enable RLS
ALTER TABLE residency_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE residency_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE residency_step_progress ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Everyone can view steps" ON residency_steps;
  DROP POLICY IF EXISTS "Users can manage own progress" ON residency_progress;
  DROP POLICY IF EXISTS "Users can manage step progress" ON residency_step_progress;
EXCEPTION
  WHEN undefined_object THEN null;
END $$;

-- Create policies
CREATE POLICY "Everyone can view steps"
  ON residency_steps
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can manage own progress"
  ON residency_progress
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

CREATE POLICY "Users can manage step progress"
  ON residency_step_progress
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM residency_progress rp 
      WHERE rp.id = residency_step_progress.progress_id 
      AND (rp.user_id = auth.uid() OR auth.jwt() ->> 'role' = 'agency')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM residency_progress rp 
      WHERE rp.id = residency_step_progress.progress_id 
      AND (rp.user_id = auth.uid() OR auth.jwt() ->> 'role' = 'agency')
    )
  );

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_residency_progress_user_id
  ON residency_progress(user_id);

CREATE INDEX IF NOT EXISTS idx_residency_step_progress_progress_id
  ON residency_step_progress(progress_id);

CREATE INDEX IF NOT EXISTS idx_residency_step_progress_step_id
  ON residency_step_progress(step_id);

-- Grant permissions
GRANT ALL ON residency_steps TO authenticated;
GRANT ALL ON residency_progress TO authenticated;
GRANT ALL ON residency_step_progress TO authenticated;
GRANT EXECUTE ON FUNCTION ensure_residency_progress TO authenticated;
GRANT EXECUTE ON FUNCTION on_auth_user_created TO authenticated;