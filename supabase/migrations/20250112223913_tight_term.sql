/*
  # Fix Residency Progress RLS Policies

  1. Changes
    - Add comprehensive policies for residency_progress table
    - Add comprehensive policies for residency_step_progress table
    - Ensure agency role has full access

  2. Security
    - Maintain RLS protection
    - Grant proper access to agency users
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own progress" ON residency_progress;
DROP POLICY IF EXISTS "Agency can view all progress" ON residency_progress;
DROP POLICY IF EXISTS "Users can view own step progress" ON residency_step_progress;
DROP POLICY IF EXISTS "Agency can manage all step progress" ON residency_step_progress;

-- Create new comprehensive policies for residency_progress
CREATE POLICY "Users and agency can access progress"
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

-- Create new comprehensive policies for residency_step_progress
CREATE POLICY "Users and agency can access step progress"
ON residency_step_progress
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 
    FROM residency_progress rp 
    WHERE rp.id = residency_step_progress.progress_id 
    AND (rp.user_id = auth.uid() OR auth.jwt() ->> 'role' = 'agency')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 
    FROM residency_progress rp 
    WHERE rp.id = residency_step_progress.progress_id 
    AND (rp.user_id = auth.uid() OR auth.jwt() ->> 'role' = 'agency')
  )
);