import React, { useState, useEffect } from 'react';
import { Home, MessageSquare, Clock, Users, Circle, AlertCircle, Search } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import ChatWindow from './ChatWindow';
import type { ChatConversation } from '../../types';

interface Props {
  onNavigateHome: () => void;
}

interface ConversationWithStatus extends ChatConversation {
  unread: boolean;
  user_email?: string;
  user_first_name?: string;
  user_last_name?: string;
  unread_count: number;
}

const getConversationStatus = (conversation: ConversationWithStatus) => {
  if (conversation.unread_count > 0) return 'open me';
  return 'Read';
};

export default function AgencyDashboard({ onNavigateHome }: Props) {
  const [conversations, setConversations] = useState<ConversationWithStatus[]>([]);
  const [selectedConversation, setSelectedConversation] = useState<ChatConversation | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    loadConversations();
    const subscription = subscribeToUpdates();
    return () => subscription();
  }, []);

  const loadConversations = async () => {
    try {
      const { data, error } = await supabase.rpc('get_chat_conversations_with_profiles');
      if (error) throw error;

      // Process and deduplicate conversations
      const emailMap = new Map<string, ConversationWithStatus>();
      
      (data || []).forEach(conv => {
        const processedConv = {
          ...conv,
          unread: conv.unread_count > 0,
          unread_count: conv.unread_count || 0
        };

        // Only keep the most recent conversation for each email
        if (conv.user_email) {
          const existingConv = emailMap.get(conv.user_email);
          if (!existingConv || new Date(conv.last_message_at || 0) > new Date(existingConv.last_message_at || 0)) {
            emailMap.set(conv.user_email, processedConv);
          }
        }
      });

      // Convert map back to array and sort
      const deduplicatedConversations = Array.from(emailMap.values())
        .sort((a, b) => {
          if (a.unread !== b.unread) return a.unread ? -1 : 1;
          return new Date(b.last_message_at || 0).getTime() - 
                 new Date(a.last_message_at || 0).getTime();
        });

      setConversations(deduplicatedConversations);
    } catch (error) {
      console.error('Error loading conversations:', error);
      setError('Error loading conversations');
    } finally {
      setIsLoading(false);
    }
  };

  const subscribeToUpdates = () => {
    const subscription = supabase
      .channel('chat_updates')
      .on(
        'postgres_changes',
        { 
          event: '*',
          schema: 'public',
          table: 'chat_messages'
        },
        () => loadConversations()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(subscription);
    };
  };

  const handleSelectConversation = async (conversation: ConversationWithStatus) => {
    setSelectedConversation(conversation);
    
    if (conversation.unread_count > 0) {
      try {
        const { error } = await supabase.rpc('mark_messages_as_read', {
          p_conversation_id: conversation.id
        });

        if (error) throw error;
        loadConversations();
      } catch (error) {
        console.error('Error marking messages as read:', error);
      }
    }
  };

  const handleMessageRead = () => {
    loadConversations();
  };

  const filteredConversations = conversations.filter(conversation => 
    conversation.user_email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    `${conversation.user_first_name} ${conversation.user_last_name}`.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 py-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center">
            <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
              <MessageSquare className="h-6 w-6 text-blue-600" />
              Chat Panel
            </h1>
            <button
              onClick={onNavigateHome}
              className="flex items-center gap-2 text-gray-600 hover:text-gray-900"
            >
              <Home className="h-5 w-5" />
              <span>Back to Panel</span>
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-6 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Conversations List */}
          <div className="bg-white rounded-lg shadow overflow-hidden">
            <div className="p-4 border-b">
              <div className="flex flex-col gap-4">
                <div className="flex justify-between items-center">
                  <h2 className="text-lg font-medium text-gray-900 flex items-center gap-2">
                    <Users className="h-5 w-5 text-gray-500" />
                    Active Conversations
                  </h2>
                </div>
                <div className="relative">
                  <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <Search className="h-5 w-5 text-gray-400" />
                  </div>
                  <input
                    type="text"
                    placeholder="Search by customer email or name..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                  />
                </div>
              </div>
            </div>

            <div className="overflow-y-auto" style={{ maxHeight: 'calc(100vh - 13rem)' }}>
              {isLoading ? (
                <div className="flex justify-center items-center p-8">
                  <Clock className="h-8 w-8 animate-spin text-blue-600" />
                </div>
              ) : error ? (
                <div className="text-center py-8">
                  <AlertCircle className="h-8 w-8 text-red-500 mx-auto mb-2" />
                  <p className="text-gray-900 font-medium">{error}</p>
                </div>
              ) : filteredConversations.length === 0 ? (
                <div className="text-center py-8 text-gray-500">
                  {searchTerm 
                    ? 'No conversations match your search' 
                    : 'No active conversations'}
                </div>
              ) : (
                <ul className="divide-y divide-gray-200">
                  {filteredConversations.map((conversation) => (
                    <li
                      key={conversation.id}
                      onClick={() => handleSelectConversation(conversation)}
                      className={`
                        cursor-pointer transition-colors
                        ${selectedConversation?.id === conversation.id ? 'bg-blue-50' : ''}
                        ${conversation.unread ? 'bg-red-50 hover:bg-red-100' : 'hover:bg-gray-50'}
                      `}
                    >
                      <div className="p-4">
                        <div className="flex justify-between items-start mb-1">
                          <div className="flex items-center gap-2">
                            {conversation.unread && (
                              <Circle className="h-2 w-2 text-red-500 fill-current" />
                            )}
                            <div>
                              <span className={`font-medium ${
                                conversation.unread ? 'text-gray-900' : 'text-gray-600'
                              }`}>
                                {conversation.user_email}
                              </span>
                              {(conversation.user_first_name || conversation.user_last_name) && (
                                <p className="text-sm text-gray-500">
                                  {conversation.user_first_name} {conversation.user_last_name}
                                </p>
                              )}
                            </div>
                          </div>
                          {conversation.unread && (
                            <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                              {conversation.unread_count}
                            </span>
                          )}
                        </div>
                        {conversation.last_message && (
                          <p className={`text-sm ${
                            conversation.unread ? 'text-gray-900 font-medium' : 'text-gray-500'
                          } truncate pl-4`}>
                            {conversation.last_message}
                          </p>
                        )}
                        <div className="mt-1 text-xs text-gray-400">
                          {getConversationStatus(conversation)}
                        </div>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </div>

          {/* Chat Window */}
          <div className="lg:col-span-2">
            {selectedConversation ? (
              <ChatWindow
                conversation={selectedConversation}
                onClose={() => setSelectedConversation(null)}
                onMessageRead={handleMessageRead}
              />
            ) : (
              <div className="bg-white rounded-lg shadow p-8 text-center">
                <MessageSquare className="h-12 w-12 text-gray-400 mx-auto mb-4" />
                <h3 className="text-lg font-medium text-gray-900 mb-2">
                  Select a conversation
                </h3>
                <p className="text-gray-500">
                  Choose a conversation from the list to view messages
                </p>
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}