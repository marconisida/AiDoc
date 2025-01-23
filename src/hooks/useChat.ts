import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import type { ChatMessage, ChatConversation } from '../types';

interface UseChatOptions {
  onMessageRead?: () => void;
}

export function useChat(conversation: ChatConversation, options?: UseChatOptions) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const markAsRead = useCallback(async () => {
    try {
      await supabase.rpc('mark_messages_as_read', {
        p_conversation_id: conversation.id
      });
      options?.onMessageRead?.();
    } catch (error) {
      console.error('Error marking messages as read:', error);
    }
  }, [conversation.id, options]);

  const loadMessages = useCallback(async () => {
    setIsLoading(true);
    try {
      const { data, error } = await supabase
        .from('chat_messages')
        .select('*')
        .eq('conversation_id', conversation.id)
        .order('created_at', { ascending: true });

      if (error) throw error;
      setMessages(data || []);
      
      // Mark messages as read after loading
      await markAsRead();
    } catch (error) {
      setError(error instanceof Error ? error : new Error('Failed to load messages'));
      console.error('Error loading messages:', error);
    } finally {
      setIsLoading(false);
    }
  }, [conversation.id, markAsRead]);

  useEffect(() => {
    loadMessages();

    // Subscribe to new messages
    const subscription = supabase
      .channel(`conversation:${conversation.id}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'chat_messages',
          filter: `conversation_id=eq.${conversation.id}`
        },
        async (payload) => {
          if (payload.eventType === 'INSERT') {
            const newMessage = payload.new as ChatMessage;
            setMessages(prev => [...prev, newMessage]);
            
            // Mark message as read if it's not from us
            if (newMessage.sender_type !== 'agency') {
              await markAsRead();
            }
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(subscription);
    };
  }, [conversation.id, loadMessages, markAsRead]);

  return {
    messages,
    isLoading,
    error,
    markAsRead,
    refresh: loadMessages
  };
}