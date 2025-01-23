import { useEffect, useState } from 'react';
import { supabase, retryOperation, checkSupabaseConnection } from '../lib/supabase';
import type { Session } from '@supabase/supabase-js';

export function useAuth() {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const [isReconnecting, setIsReconnecting] = useState(false);

  const attemptReconnection = async () => {
    setIsReconnecting(true);
    try {
      const isConnected = await checkSupabaseConnection();
      if (isConnected) {
        setError(null);
        const { data: { session: newSession } } = await retryOperation(() =>
          supabase.auth.getSession()
        );
        setSession(newSession);
      }
    } catch (error) {
      console.error('Reconnection error:', error);
      setError(error instanceof Error ? error : new Error('Connection error'));
    } finally {
      setIsReconnecting(false);
    }
  };

  useEffect(() => {
    let mounted = true;
    let reconnectInterval: NodeJS.Timeout;

    const initialize = async () => {
      try {
        // Get initial session
        const { data: { session: initialSession }, error: sessionError } = 
          await supabase.auth.getSession();
        
        if (sessionError) throw sessionError;
        
        if (mounted) {
          setSession(initialSession);
          setLoading(false);
        }

        // Set up auth state change listener
        const {
          data: { subscription },
        } = supabase.auth.onAuthStateChange(async (_event, session) => {
          if (mounted) {
            setSession(session);
            
            if (session) {
              const isConnected = await checkSupabaseConnection();
              if (!isConnected) {
                setError(new Error('Connection lost. Attempting to reconnect...'));
                reconnectInterval = setInterval(attemptReconnection, 5000);
              } else {
                setError(null);
                if (reconnectInterval) {
                  clearInterval(reconnectInterval);
                }
              }
            }
          }
        });

        return () => {
          mounted = false;
          subscription.unsubscribe();
          if (reconnectInterval) {
            clearInterval(reconnectInterval);
          }
        };
      } catch (error) {
        if (mounted) {
          console.error('Auth initialization error:', error);
          setError(error instanceof Error ? error : new Error('Authentication error'));
          setLoading(false);
        }
      }
    };

    initialize();

    return () => {
      mounted = false;
      if (reconnectInterval) {
        clearInterval(reconnectInterval);
      }
    };
  }, []);

  return { session, loading, error, isReconnecting, attemptReconnection };
}