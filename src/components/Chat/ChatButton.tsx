import React, { useState, useEffect } from 'react';
import { MessageSquare } from 'lucide-react';
import { supabase, retryOperation } from '../../lib/supabase';
import { useAuth } from '../../hooks/useAuth';
import type { ChatConversation } from '../../types';
import ChatWindow from './ChatWindow';

export default function ChatButton() {
  const { session } = useAuth();
  const [isOpen, setIsOpen] = useState(false);
  const [conversation, setConversation] = useState<ChatConversation | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (session?.user) {
      loadOrCreateConversation();
    }
  }, [session]);

  const loadOrCreateConversation = async () => {
    if (!session?.user) return;
    
    setIsLoading(true);
    try {
      // First try to find an existing active conversation
      const { data: conversations, error: fetchError } = await retryOperation(() =>
        supabase
          .from('chat_conversations')
          .select('*')
          .eq('user_id', session.user.id)
          .eq('status', 'active')
          .order('created_at', { ascending: false })
          .limit(1)
      );

      if (fetchError) throw fetchError;

      if (conversations && conversations.length > 0) {
        setConversation(conversations[0]);
        return;
      }

      // If no conversation exists, create a new one
      const { data: newConversation, error: insertError } = await retryOperation(() =>
        supabase
          .from('chat_conversations')
          .insert({
            user_id: session.user.id,
            status: 'active',
            is_bot_active: true
          })
          .select()
          .single()
      );

      if (insertError) throw insertError;

      // Add the user as a participant
      const { error: participantError } = await retryOperation(() =>
        supabase
          .from('chat_participants')
          .insert({
            conversation_id: newConversation.id,
            user_id: session.user.id,
            role: 'user'
          })
      );

      if (participantError) throw participantError;

      setConversation(newConversation);
    } catch (error) {
      console.error('Error managing conversation:', error);
      // Don't throw here, just log the error and let the user try again
    } finally {
      setIsLoading(false);
    }
  };

  const handleToggleChat = () => {
    if (!isOpen && !conversation) {
      loadOrCreateConversation();
    }
    setIsOpen(!isOpen);
  };

  if (!session) return null;

  return (
    <>
      <button
        onClick={handleToggleChat}
        className="fixed bottom-4 right-4 p-4 bg-blue-600 text-white rounded-full shadow-lg hover:bg-blue-700 transition-colors"
        aria-label="Support Chat"
        disabled={isLoading}
      >
        <MessageSquare className="h-6 w-6" />
      </button>

      {isOpen && conversation && (
        <ChatWindow
          conversation={conversation}
          onClose={() => setIsOpen(false)}
        />
      )}
    </>
  );
}