/*
  # Chat System Implementation

  1. New Tables
    - `chat_conversations`
      - Stores chat conversations between users and agency/bot
    - `chat_messages`
      - Stores individual chat messages
    - `chat_participants`
      - Tracks participants in each conversation

  2. Security
    - Enable RLS on all tables
    - Add policies for users and agency access
*/

-- Create chat conversations table
CREATE TABLE IF NOT EXISTS chat_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  agency_id uuid REFERENCES auth.users(id),
  status text NOT NULL DEFAULT 'active',
  last_message text,
  last_message_at timestamptz,
  is_bot_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create chat messages table
CREATE TABLE IF NOT EXISTS chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid REFERENCES chat_conversations(id) ON DELETE CASCADE,
  sender_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  sender_type text NOT NULL,
  content text NOT NULL,
  created_at timestamptz DEFAULT now(),
  read_at timestamptz
);

-- Create chat participants table
CREATE TABLE IF NOT EXISTS chat_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid REFERENCES chat_conversations(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL,
  last_read_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

-- Enable RLS
ALTER TABLE chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_participants ENABLE ROW LEVEL SECURITY;

-- Create policies for chat_conversations
CREATE POLICY "Users can view their conversations"
  ON chat_conversations
  FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid() OR
    agency_id = auth.uid() OR
    auth.jwt() ->> 'role' = 'agency'
  );

CREATE POLICY "Users can create conversations"
  ON chat_conversations
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Create policies for chat_messages
CREATE POLICY "Users can view conversation messages"
  ON chat_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_participants
      WHERE conversation_id = chat_messages.conversation_id
      AND user_id = auth.uid()
    ) OR
    auth.jwt() ->> 'role' = 'agency'
  );

CREATE POLICY "Users can send messages"
  ON chat_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM chat_participants
      WHERE conversation_id = chat_messages.conversation_id
      AND user_id = auth.uid()
    ) OR
    auth.jwt() ->> 'role' = 'agency'
  );

-- Create policies for chat_participants
CREATE POLICY "Users can view participants"
  ON chat_participants
  FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid() OR
    auth.jwt() ->> 'role' = 'agency'
  );

CREATE POLICY "Users can join conversations"
  ON chat_participants
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid() OR
    auth.jwt() ->> 'role' = 'agency'
  );

-- Create function to update conversation timestamps
CREATE OR REPLACE FUNCTION update_conversation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE chat_conversations
  SET 
    updated_at = now(),
    last_message = NEW.content,
    last_message_at = NEW.created_at
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for conversation updates
CREATE TRIGGER update_conversation_on_message
  AFTER INSERT ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_timestamp();