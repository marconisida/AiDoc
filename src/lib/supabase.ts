import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  throw new Error('Missing Supabase environment variables');
}

// Create Supabase client with minimal configuration
export const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    storageKey: 'supabase.auth.token',
    storage: window.localStorage
  }
});

// Maximum number of retries
const MAX_RETRIES = 3;
const BASE_DELAY = 1000;

// Retry operation with exponential backoff
export const retryOperation = async <T>(
  operation: () => Promise<T>,
  maxRetries: number = MAX_RETRIES
): Promise<T> => {
  let lastError: any;
  
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      if (attempt > 0) {
        const delay = Math.min(BASE_DELAY * Math.pow(2, attempt), 5000);
        await new Promise(resolve => setTimeout(resolve, delay));
      }

      return await operation();
    } catch (error: any) {
      lastError = error;
      console.error(`Attempt ${attempt + 1} failed:`, error);
      
      if (attempt === maxRetries - 1) {
        throw error;
      }
    }
  }
  
  throw lastError;
};

// Check Supabase connection
export const checkSupabaseConnection = async (): Promise<boolean> => {
  try {
    const { error } = await supabase
      .from('documents')
      .select('id')
      .limit(1)
      .maybeSingle();

    if (error) {
      if (error.message?.includes('JWT') || error.message?.includes('auth')) {
        const { error: refreshError } = await supabase.auth.refreshSession();
        return !refreshError;
      }
      return !error.message?.includes('Failed to fetch');
    }

    return true;
  } catch (error) {
    console.error('Connection check error:', error);
    return false;
  }
};