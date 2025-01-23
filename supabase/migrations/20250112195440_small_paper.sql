/*
  # Residency Progress Tracking System

  1. New Tables
    - `residency_progress`
      - Main table tracking overall progress
      - Stores user_id, current step, and overall status
    - `residency_steps`
      - Predefined steps for the residency process
      - Contains title, description, and order
    - `residency_step_progress`
      - Tracks individual step progress for each user
      - Links steps to user's progress
      - Stores status, completion dates, and notes

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users to read their own data
    - Add policies for agency staff to manage all records
*/

-- Create enum for step status
CREATE TYPE step_status AS ENUM (
  'pending',
  'in_progress',
  'completed',
  'blocked'
);

-- Create enum for overall progress status
CREATE TYPE progress_status AS ENUM (
  'active',
  'completed',
  'blocked'
);

-- Create residency progress table
CREATE TABLE IF NOT EXISTS residency_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  current_step integer NOT NULL DEFAULT 1,
  status progress_status NOT NULL DEFAULT 'active',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (user_id)
);

-- Create predefined steps table
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

-- Create step progress table
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

-- Enable RLS
ALTER TABLE residency_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE residency_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE residency_step_progress ENABLE ROW LEVEL SECURITY;

-- Policies for residency_progress
CREATE POLICY "Users can view own progress"
  ON residency_progress
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Agency can view all progress"
  ON residency_progress
  FOR ALL
  TO authenticated
  USING (auth.jwt() ->> 'role' = 'agency');

-- Policies for residency_steps
CREATE POLICY "Everyone can view steps"
  ON residency_steps
  FOR SELECT
  TO authenticated
  USING (true);

-- Policies for residency_step_progress
CREATE POLICY "Users can view own step progress"
  ON residency_step_progress
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM residency_progress
      WHERE id = residency_step_progress.progress_id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "Agency can manage all step progress"
  ON residency_step_progress
  FOR ALL
  TO authenticated
  USING (auth.jwt() ->> 'role' = 'agency');

-- Insert predefined steps
INSERT INTO residency_steps (title, description, order_number, estimated_time, requirements) VALUES
  (
    'Subida de Documentos',
    'Envío y revisión inicial de documentos requeridos en formato digital',
    1,
    '1-2 días hábiles',
    ARRAY['Documentos escaneados', 'Pasaporte vigente']
  ),
  (
    'Traducción y Notarización',
    'Traducción oficial al español y notarización de documentos extranjeros',
    2,
    '3-7 días hábiles',
    ARRAY['Documentos originales', 'Pago de tasas de traducción']
  ),
  (
    'Cita en Migraciones',
    'Presentación física de documentos y entrevista en Migraciones',
    3,
    '1 día',
    ARRAY['Documentos originales', 'Pasaporte', 'Comprobante de pago de tasas']
  ),
  (
    'Emisión de Residencia',
    'Seguimiento y procesamiento del expediente en Migraciones',
    4,
    '30-60 días',
    ARRAY['Expediente completo']
  ),
  (
    'Tramitación de Cédula',
    'Gestión de la cédula paraguaya en el Departamento de Identificaciones',
    5,
    '7-10 días hábiles',
    ARRAY['Carnet de residencia', 'Fotos', 'Huellas digitales']
  ),
  (
    'Recepción de Cédula',
    'Entrega física de la cédula paraguaya',
    6,
    '1-2 días hábiles',
    ARRAY['Comprobante de trámite']
  ),
  (
    'Tramitación del RUC',
    'Registro ante Hacienda para obtener el RUC',
    7,
    '3-5 días hábiles',
    ARRAY['Cédula paraguaya', 'Residencia vigente']
  ),
  (
    'Recepción del RUC',
    'Entrega del documento oficial del RUC y finalización del proceso',
    8,
    '1-2 días hábiles',
    ARRAY['Documentación completa']
  );

-- Create function to update progress timestamps
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for timestamp updates
CREATE TRIGGER update_residency_progress_timestamp
  BEFORE UPDATE ON residency_progress
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_residency_step_progress_timestamp
  BEFORE UPDATE ON residency_step_progress
  FOR EACH ROW
  EXECUTE FUNCTION update_timestamp();