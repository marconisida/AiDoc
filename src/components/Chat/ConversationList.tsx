import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { MessageSquare, Circle } from 'lucide-react';

interface Conversation {
  id: string;
  user_email: string;
  last_message: string | null;
  last_message_at: string | null;
  unread_count: number;
  is_read: boolean;
}

interface Props {
  onSelectConversation: (conversation: Conversation) => void;
  selectedId?: string;
}

export default function ConversationList({ onSelectConversation, selectedId }: Props) {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadConversations();
    subscribeToUpdates();
  }, []);

  const loadConversations = async () => {
    try {
      const { data, error } = await supabase
        .rpc('get_conversations_with_status');

      if (error) throw error;
      setConversations(data || []);
    } catch (error) {
      console.error('Error loading conversations:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const subscribeToUpdates = () => {
    const subscription = supabase
      .channel('conversation_updates')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'chat_messages' },
        () => loadConversations()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(subscription);
    };
  };

  if (isLoading) {
    return (
      <div className="flex justify-center items-center p-8">
        <div className="animate-spin rounded-full h-8 w-8 border-2 border-blue-500 border-t-transparent"></div>
      </div>
    );
  }

  if (conversations.length === 0) {
    return (
      <div className="text-center py-8">
        <MessageSquare className="h-8 w-8 text-gray-400 mx-auto mb-2" />
        <p className="text-gray-500">No hay conversaciones activas</p>
      </div>
    );
  }

  return (
    <ul className="divide-y divide-gray-200">
      {conversations.map((conversation) => (
        <li
          key={conversation.id}
          onClick={() => onSelectConversation(conversation)}
          className={`
            cursor-pointer p-4 hover:bg-gray-50 transition-colors
            ${selectedId === conversation.id ? 'bg-blue-50' : ''}
            ${!conversation.is_read ? 'bg-red-50' : ''}
          `}
        >
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-2">
              {!conversation.is_read && (
                <Circle className="h-2 w-2 text-red-500 fill-current" />
              )}
              <span className={`font-medium ${!conversation.is_read ? 'text-gray-900' : 'text-gray-600'}`}>
                {conversation.user_email}
              </span>
            </div>
            {!conversation.is_read && conversation.unread_count > 0 && (
              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                {conversation.unread_count}
              </span>
            )}
          </div>
          {conversation.last_message && (
            <p className={`mt-1 text-sm ${!conversation.is_read ? 'text-gray-900' : 'text-gray-500'} truncate pl-4`}>
              {conversation.last_message}
            </p>
          )}
          <div className="mt-1 text-xs text-gray-400">
            {conversation.last_message_at ? (
              new Date(conversation.last_message_at).toLocaleString()
            ) : (
              'Sin mensajes'
            )}
          </div>
        </li>
      ))}
    </ul>
  );
}