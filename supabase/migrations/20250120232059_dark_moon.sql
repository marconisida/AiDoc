-- Add client_notes column to ruc_info table
ALTER TABLE ruc_info 
ADD COLUMN IF NOT EXISTS client_notes text;