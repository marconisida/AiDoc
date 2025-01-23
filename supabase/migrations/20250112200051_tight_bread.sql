/*
  # Fix residency progress policies

  1. Changes
    - Add insert policy for users to create their own progress
    - Add insert policy for users to create their own step progress
    - Add update policy for users to update their own progress status
    - Add update policy for users to update their own step progress

  2. Security
    - Users can only create/update their own records
    - Agency role maintains full access
*/

-- Add insert policy for residency_progress
CREATE POLICY "Users can create own progress"
  ON residency_progress
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Add update policy for residency_progress
CREATE POLICY "Users can update own progress"
  ON residency_progress
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Add insert policy for residency_step_progress
CREATE POLICY "Users can create own step progress"
  ON residency_step_progress
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM residency_progress
      WHERE id = residency_step_progress.progress_id
      AND user_id = auth.uid()
    )
  );

-- Add update policy for residency_step_progress
CREATE POLICY "Users can update own step progress"
  ON residency_step_progress
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM residency_progress
      WHERE id = residency_step_progress.progress_id
      AND user_id = auth.uid()
    )
  );