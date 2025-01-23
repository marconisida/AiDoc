import { useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { getBotResponse } from '../utils/chatbot';
import type { ChatMessage, ChatConversation } from '../types';

export function useChatBot(conversation: ChatConversation) {
  const handleBotResponse = useCallback(async (messages: ChatMessage[]) => {
    if (!conversation.is_bot_active) return;

    const lastMessage = messages[messages.length - 1];
    if (lastMessage.sender_type === 'bot' || lastMessage.sender_type === 'agency') return;

    try {
      const botResponse = await getBotResponse(messages);
      
      if (botResponse.confidence < 0.7) {
        // Low confidence, notify agency
        await supabase
          .from('chat_conversations')
          .update({ 
            is_bot_active: false,
            agency_id: null // Clear agency ID to indicate need for assignment
          })
          .eq('id', conversation.id);

        botResponse.content += '\n\nPermítame conectarlo con un agente humano para mejor asistencia.';
      }

      await supabase
        .from('chat_messages')
        .insert({
          conversation_id: conversation.id,
          sender_id: null, // Bot messages don't have a sender_id
          sender_type: 'bot',
          content: botResponse.content
        });
    } catch (error) {
      console.error('Bot handling error:', error);
    }
  }, [conversation]);

  useEffect(() => {
    const subscription = supabase
      .channel(`conversation:${conversation.id}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'chat_messages',
          filter: `conversation_id=eq.${conversation.id}`
        },
        async (payload) => {
          const { data: messages, error } = await supabase
            .from('chat_messages')
            .select('*')
            .eq('conversation_id', conversation.id)
            .order('created_at', { ascending: true });

          if (error) {
            console.error('Error fetching messages:', error);
            return;
          }

          handleBotResponse(messages);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(subscription);
    };
  }, [conversation.id, handleBotResponse]);
}