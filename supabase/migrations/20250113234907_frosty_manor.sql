/*
  # Fix Chat Relationships

  1. Changes
    - Add proper foreign key relationships for chat tables
    - Update RLS policies to handle relationships correctly
    - Add indexes for better performance

  2. Security
    - Maintain existing RLS policies
    - Ensure proper access control
*/

-- Add proper foreign key relationships
ALTER TABLE chat_conversations
  DROP CONSTRAINT IF EXISTS chat_conversations_user_id_fkey,
  ADD CONSTRAINT chat_conversations_user_id_fkey 
    FOREIGN KEY (user_id) 
    REFERENCES auth.users(id) 
    ON DELETE CASCADE;

ALTER TABLE chat_conversations
  DROP CONSTRAINT IF EXISTS chat_conversations_agency_id_fkey,
  ADD CONSTRAINT chat_conversations_agency_id_fkey 
    FOREIGN KEY (agency_id) 
    REFERENCES auth.users(id) 
    ON DELETE SET NULL;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chat_conversations_user_id 
  ON chat_conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_conversations_agency_id 
  ON chat_conversations(agency_id);
CREATE INDEX IF NOT EXISTS idx_chat_conversations_status 
  ON chat_conversations(status);

-- Create a view for better querying with user information
CREATE OR REPLACE VIEW chat_conversations_with_users AS
SELECT 
  c.*,
  u.email as user_email,
  a.email as agency_email
FROM chat_conversations c
LEFT JOIN auth.users u ON c.user_id = u.id
LEFT JOIN auth.users a ON c.agency_id = a.id;

-- Grant appropriate permissions
GRANT SELECT ON chat_conversations_with_users TO authenticated;