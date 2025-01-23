-- Create tables for RUC functionality
CREATE TABLE IF NOT EXISTS ruc_info (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  marungatu_username text,
  marungatu_password text,
  agency_notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id)
);

CREATE TABLE IF NOT EXISTS certificate_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('compliance', 'residency')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE ruc_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE certificate_requests ENABLE ROW LEVEL SECURITY;

-- Create policies for ruc_info
CREATE POLICY "Users can view own RUC info"
  ON ruc_info
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id OR 
    auth.jwt() ->> 'role' = 'agency'
  );

CREATE POLICY "Agency can manage RUC info"
  ON ruc_info
  FOR ALL
  TO authenticated
  USING (auth.jwt() ->> 'role' = 'agency')
  WITH CHECK (auth.jwt() ->> 'role' = 'agency');

-- Create policies for certificate_requests
CREATE POLICY "Users can manage own certificate requests"
  ON certificate_requests
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

-- Create trigger function to update timestamps
CREATE OR REPLACE FUNCTION update_ruc_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER update_ruc_info_timestamp
  BEFORE UPDATE ON ruc_info
  FOR EACH ROW
  EXECUTE FUNCTION update_ruc_timestamp();

CREATE TRIGGER update_certificate_request_timestamp
  BEFORE UPDATE ON certificate_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_ruc_timestamp();

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_ruc_info_user_id
  ON ruc_info(user_id);

CREATE INDEX IF NOT EXISTS idx_certificate_requests_user_id
  ON certificate_requests(user_id);

CREATE INDEX IF NOT EXISTS idx_certificate_requests_status
  ON certificate_requests(status);

-- Grant necessary permissions
GRANT ALL ON ruc_info TO authenticated;
GRANT ALL ON certificate_requests TO authenticated;