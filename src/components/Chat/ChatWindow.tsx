import React, { useState, useEffect, useRef } from 'react';
import { X, Send, Loader2, AlertCircle } from 'lucide-react';
import { supabase, retryOperation } from '../../lib/supabase';
import { useAuth } from '../../hooks/useAuth';
import { useChatBot } from '../../hooks/useChatBot';
import type { ChatMessage, ChatConversation } from '../../types';

interface Props {
  conversation: ChatConversation;
  onClose: () => void;
  onMessageRead?: () => void;
}

export default function ChatWindow({ conversation, onClose, onMessageRead }: Props) {
  const { session } = useAuth();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isSending, setIsSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const chatContainerRef = useRef<HTMLDivElement>(null);
  const isAgency = session?.user?.user_metadata?.role === 'agency';

  useChatBot(conversation);

  useEffect(() => {
    loadMessages();
    const unsubscribe = subscribeToMessages();
    return () => unsubscribe();
  }, [conversation.id]);

  useEffect(() => {
    const markUnreadMessages = async () => {
      if (!isAgency || messages.length === 0) return;

      try {
        const { error } = await retryOperation(() =>
          supabase.rpc('mark_messages_as_read', {
            p_conversation_id: conversation.id
          })
        );

        if (error) throw error;

        setMessages(current =>
          current.map(msg =>
            msg.read_at ? msg : { ...msg, read_at: new Date().toISOString() }
          )
        );

        onMessageRead?.();
      } catch (error) {
        console.error('Error marking messages as read:', error);
        setError('Error marking messages as read. Changes will sync automatically.');
      }
    };

    markUnreadMessages();

    const handleFocus = () => markUnreadMessages();
    window.addEventListener('focus', handleFocus);
    
    return () => window.removeEventListener('focus', handleFocus);
  }, [isAgency, messages, onMessageRead, conversation.id]);

  const loadMessages = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const { data, error } = await retryOperation(() =>
        supabase
          .from('chat_messages')
          .select('*')
          .eq('conversation_id', conversation.id)
          .order('created_at', { ascending: true })
      );

      if (error) throw error;
      setMessages(data || []);
      scrollToBottom();

      if (isAgency && data) {
        const { error: markError } = await retryOperation(() =>
          supabase.rpc('mark_messages_as_read', {
            p_conversation_id: conversation.id
          })
        );

        if (!markError) {
          onMessageRead?.();
        }
      }
    } catch (error) {
      console.error('Error loading messages:', error);
      setError('Error loading messages. Attempting to reconnect...');
      
      // Retry loading after a delay
      setTimeout(loadMessages, 3000);
    } finally {
      setIsLoading(false);
    }
  };

  const subscribeToMessages = () => {
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
            scrollToBottom();
            
            if (isAgency && newMessage.sender_type !== 'agency' && !newMessage.read_at) {
              try {
                const { error } = await retryOperation(() =>
                  supabase.rpc('mark_messages_as_read', {
                    p_conversation_id: conversation.id,
                    p_up_to_message_id: newMessage.id
                  })
                );

                if (!error) {
                  onMessageRead?.();
                }
              } catch (error) {
                console.error('Error marking message as read:', error);
              }
            }
          } else if (payload.eventType === 'UPDATE') {
            setMessages(current =>
              current.map(msg =>
                msg.id === payload.new.id ? { ...msg, ...payload.new } : msg
              )
            );
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(subscription);
    };
  };

  const scrollToBottom = () => {
    if (messagesEndRef.current) {
      messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  };

  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim() || !session?.user) return;

    const messageContent = newMessage.trim();
    setNewMessage('');
    
    // Optimistically add message to UI
    const optimisticMessage: ChatMessage = {
      id: crypto.randomUUID(),
      conversation_id: conversation.id,
      sender_id: session.user.id,
      sender_type: isAgency ? 'agency' : 'user',
      content: messageContent,
      created_at: new Date().toISOString()
    };
    
    setMessages(current => [...current, optimisticMessage]);
    scrollToBottom();

    setIsSending(true);
    try {
      const { error } = await retryOperation(() =>
        supabase
          .from('chat_messages')
          .insert({
            conversation_id: conversation.id,
            sender_id: session.user.id,
            sender_type: isAgency ? 'agency' : 'user',
            content: messageContent
          })
      );

      if (error) throw error;
    } catch (error) {
      console.error('Error sending message:', error);
      // Remove optimistic message on error
      setMessages(current => current.filter(msg => msg.id !== optimisticMessage.id));
      setError('Error sending message. Please try again.');
    } finally {
      setIsSending(false);
    }
  };

  return (
    <div className="fixed inset-0 lg:relative bg-white lg:rounded-lg lg:shadow-lg flex flex-col h-[calc(100vh-2rem)] lg:h-[calc(100vh-10rem)] overflow-hidden">
      {/* Chat Header */}
      <div className="flex items-center justify-between p-4 border-b bg-white">
        <h3 className="text-lg font-medium">
          {isAgency ? conversation.user_email : 'Support Chat'}
        </h3>
        <button
          onClick={onClose}
          className="text-gray-500 hover:text-gray-700"
        >
          <X className="h-5 w-5" />
        </button>
      </div>

      {/* Messages */}
      <div
        ref={chatContainerRef}
        className="flex-1 overflow-y-auto p-4 space-y-4"
        style={{ height: 'calc(100% - 8rem)' }}
      >
        {isLoading ? (
          <div className="flex justify-center items-center h-full">
            <Loader2 className="h-8 w-8 animate-spin text-blue-600" />
          </div>
        ) : messages.length === 0 ? (
          <div className="text-center text-gray-500">
            No messages yet
          </div>
        ) : (
          messages.map((message) => (
            <div
              key={message.id}
              className={`flex ${
                message.sender_type === (isAgency ? 'agency' : 'user')
                  ? 'justify-end'
                  : 'justify-start'
              }`}
            >
              <div
                className={`max-w-[75%] rounded-lg px-4 py-2 ${
                  message.sender_type === (isAgency ? 'agency' : 'user')
                    ? 'bg-blue-600 text-white'
                    : message.sender_type === 'bot'
                    ? 'bg-gray-100 text-gray-800'
                    : 'bg-gray-200 text-gray-800'
                }`}
              >
                <p className="whitespace-pre-wrap break-words">{message.content}</p>
                <div className="flex items-center justify-between gap-2 mt-1 text-xs opacity-75">
                  <span>
                    {new Date(message.created_at).toLocaleTimeString([], {
                      hour: '2-digit',
                      minute: '2-digit'
                    })}
                  </span>
                  {message.read_at && message.sender_type !== 'agency' && (
                    <span className="text-xs opacity-75">
                      Read
                    </span>
                  )}
                </div>
              </div>
            </div>
          ))
        )}
        <div ref={messagesEndRef} />
      </div>

      {error && (
        <div className="p-2 bg-red-50 border-t border-red-100">
          <div className="flex items-center gap-2 text-red-700 text-sm">
            <AlertCircle className="h-4 w-4 flex-shrink-0" />
            <span>{error}</span>
          </div>
        </div>
      )}

      {/* Message Input */}
      <div className="p-4 border-t bg-white mt-auto">
        <form onSubmit={handleSendMessage} className="flex gap-2">
          <input
            type="text"
            value={newMessage}
            onChange={(e) => setNewMessage(e.target.value)}
            placeholder="Type your message..."
            className="flex-1 rounded-lg border border-gray-300 px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={isSending}
          />
          <button
            type="submit"
            disabled={isSending || !newMessage.trim()}
            className={`px-4 py-2 rounded-lg ${
              isSending || !newMessage.trim()
                ? 'bg-gray-300 cursor-not-allowed'
                : 'bg-blue-600 hover:bg-blue-700'
            } text-white flex items-center gap-2 min-w-[100px] justify-center`}
          >
            {isSending ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Send className="h-4 w-4" />
            )}
            <span>Send</span>
          </button>
        </form>
      </div>
    </div>
  );
}