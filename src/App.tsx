import React, { useEffect, useState } from 'react';
import { supabase, checkSupabaseConnection, retryOperation } from './lib/supabase';
import { FileCheck, ClipboardList, Users, MessageSquare, AlertCircle, User } from 'lucide-react';
import DocumentAnalyzer from './components/DocumentAnalyzer';
import DocumentResult from './components/DocumentResult';
import ResidencyProgress from './components/ResidencyProgress';
import Auth from './components/Auth';
import UserDocuments from './components/UserDocuments';
import AgencyCustomerList from './components/AgencyCustomerList';
import AgencyDashboard from './components/Chat/AgencyDashboard';
import ChatButton from './components/Chat/ChatButton';
import UserProfile from './components/UserProfile';
import type { AnalysisResult, UserDocument, ResidencyProgress as ResidencyProgressType } from './types';
import { useAuth } from './hooks/useAuth';
import ChatWindow from './components/Chat/ChatWindow';

export default function App() {
  const { session, loading } = useAuth();
  const [result, setResult] = useState<AnalysisResult | null>(null);
  const [documents, setDocuments] = useState<UserDocument[]>([]);
  const [connectionError, setConnectionError] = useState(false);
  const [activeTab, setActiveTab] = useState<'documents' | 'progress' | 'customers' | 'chat' | 'profile'>('profile');
  const [residencyProgress, setResidencyProgress] = useState<ResidencyProgressType | null>(null);
  const [isLoadingProgress, setIsLoadingProgress] = useState(false);
  const [selectedCustomerId, setSelectedCustomerId] = useState<string | null>(null);
  const [selectedCustomerEmail, setSelectedCustomerEmail] = useState<string | null>(null);
  const [conversation, setConversation] = useState<any>(null);

  const isAgency = session?.user?.user_metadata?.role === 'agency';

  useEffect(() => {
    const checkConnection = async () => {
      const isConnected = await checkSupabaseConnection();
      setConnectionError(!isConnected);
    };
    checkConnection();
  }, []);

  useEffect(() => {
    if (session?.user) {
      const userId = selectedCustomerId || session.user.id;
      loadUserDocuments(userId);
      if (activeTab === 'progress') {
        loadResidencyProgress(userId);
      }
      if (activeTab === 'chat' && !isAgency) {
        loadOrCreateConversation();
      }
    }
  }, [session, selectedCustomerId, activeTab]);

  const loadOrCreateConversation = async () => {
    if (!session?.user) return;
    
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
    }
  };

  const loadUserDocuments = async (userId: string) => {
    try {
      const { data, error: fetchError } = await retryOperation(() => 
        supabase
          .from('documents')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', { ascending: false })
      );

      if (fetchError) throw fetchError;
      setDocuments(data || []);
    } catch (error) {
      console.error('Error loading documents:', error);
      if (error instanceof Error && error.message.includes('Failed to fetch')) {
        setConnectionError(true);
      }
    }
  };

  const loadResidencyProgress = async (userId: string) => {
    setIsLoadingProgress(true);
    try {
      const { data: progressData, error: progressError } = await retryOperation(() =>
        supabase
          .from('residency_progress')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle()
      );

      if (progressError) throw progressError;

      if (!progressData) {
        setResidencyProgress(null);
        return;
      }

      const { data: stepsData, error: stepsError } = await retryOperation(() =>
        supabase
          .from('residency_steps')
          .select(`
            id,
            title,
            description,
            order_number,
            estimated_time,
            requirements,
            residency_step_progress!inner (
              status,
              notes,
              completed_at
            )
          `)
          .eq('residency_step_progress.progress_id', progressData.id)
          .order('order_number')
      );

      if (stepsError) throw stepsError;

      setResidencyProgress({
        ...progressData,
        steps: stepsData.map(step => ({
          id: step.id,
          title: step.title,
          description: step.description,
          order: step.order_number,
          estimatedTime: step.estimated_time,
          requirements: step.requirements,
          status: step.residency_step_progress[0].status,
          notes: step.residency_step_progress[0].notes,
          completedAt: step.residency_step_progress[0].completed_at
        }))
      });
    } catch (error) {
      console.error('Error loading progress:', error);
      if (error instanceof Error && error.message.includes('Failed to fetch')) {
        setConnectionError(true);
      }
    } finally {
      setIsLoadingProgress(false);
    }
  };

  const handleCustomerSelect = (userId: string, email: string) => {
    setSelectedCustomerId(userId);
    setSelectedCustomerEmail(email);
    setActiveTab('progress');
  };

  const handleAnalysisResult = async (analysisResult: AnalysisResult & { file_path: string }) => {
    setResult(analysisResult);
    
    if (session?.user) {
      try {
        const { error } = await supabase.from('documents').insert({
          user_id: selectedCustomerId || session.user.id,
          document_type: analysisResult.documentType,
          analysis_result: analysisResult,
          file_path: analysisResult.file_path
        });

        if (error) throw error;
        loadUserDocuments(selectedCustomerId || session.user.id);
      } catch (error) {
        console.error('Error saving document:', error);
        if (error instanceof Error && error.message.includes('Failed to fetch')) {
          setConnectionError(true);
        }
      }
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (connectionError) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="bg-white p-8 rounded-lg shadow-lg max-w-md w-full">
          <div className="flex items-center justify-center mb-4">
            <AlertCircle className="h-12 w-12 text-red-500" />
          </div>
          <h2 className="text-xl font-semibold text-center mb-4">
            Connection Error
          </h2>
          <p className="text-gray-600 text-center mb-6">
            Could not establish connection to the server. Please check your internet connection and try again.
          </p>
          <button
            onClick={() => window.location.reload()}
            className="w-full bg-blue-600 text-white py-2 px-4 rounded-lg hover:bg-blue-700 transition-colors"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  if (!session) {
    return <Auth />;
  }

  if (activeTab === 'chat' && isAgency) {
    return <AgencyDashboard onNavigateHome={() => setActiveTab('customers')} />;
  }

  const displayEmail = isAgency ? selectedCustomerEmail || session.user.email : session.user.email;

  return (
    <div className="min-h-screen bg-gradient-to-b from-blue-50 to-white">
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 py-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center">
            <div className="flex items-center gap-4">
              <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
                <FileCheck className="text-blue-600" />
                {isAgency ? 'Agency Panel' : 'Document Review Assistant'}
              </h1>
              <div className="text-sm text-gray-600 flex items-center gap-2">
                <User className="h-4 w-4" />
                {displayEmail}
              </div>
            </div>
            <button
              onClick={() => supabase.auth.signOut()}
              className="text-sm text-gray-600 hover:text-gray-900"
            >
              Sign Out
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-8 sm:px-6 lg:px-8">
        <div className="mb-6">
          <div className="border-b border-gray-200">
            <nav className="-mb-px flex space-x-8">
              {isAgency && (
                <>
                  <button
                    onClick={() => setActiveTab('customers')}
                    className={`py-4 px-1 border-b-2 font-medium text-sm ${
                      activeTab === 'customers'
                        ? 'border-blue-500 text-blue-600'
                        : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                    }`}
                  >
                    <Users className="inline-block h-5 w-5 mr-2" />
                    Customers
                  </button>
                  <button
                    onClick={() => setActiveTab('chat')}
                    className={`py-4 px-1 border-b-2 font-medium text-sm ${
                      activeTab === 'chat'
                        ? 'border-blue-500 text-blue-600'
                        : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                    }`}
                  >
                    <MessageSquare className="inline-block h-5 w-5 mr-2" />
                    Chat
                  </button>
                </>
              )}
              <button
                onClick={() => setActiveTab('documents')}
                className={`py-4 px-1 border-b-2 font-medium text-sm ${
                  activeTab === 'documents'
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                <FileCheck className="inline-block h-5 w-5 mr-2" />
                Documents
              </button>
              <button
                onClick={() => setActiveTab('progress')}
                className={`py-4 px-1 border-b-2 font-medium text-sm ${
                  activeTab === 'progress'
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                <ClipboardList className="inline-block h-5 w-5 mr-2" />
                Residency Progress
              </button>
              {!isAgency && (
                <button
                  onClick={() => setActiveTab('chat')}
                  className={`py-4 px-1 border-b-2 font-medium text-sm ${
                    activeTab === 'chat'
                      ? 'border-blue-500 text-blue-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  <MessageSquare className="inline-block h-5 w-5 mr-2" />
                  Chat
                </button>
              )}
              <button
                onClick={() => setActiveTab('profile')}
                className={`py-4 px-1 border-b-2 font-medium text-sm ${
                  activeTab === 'profile'
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                <User className="inline-block h-5 w-5 mr-2" />
                Profile
              </button>
            </nav>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-lg p-6">
          <div className="max-w-3xl mx-auto">
            {activeTab === 'customers' && isAgency ? (
              <AgencyCustomerList onSelectCustomer={handleCustomerSelect} />
            ) : activeTab === 'documents' ? (
              <>
                <DocumentAnalyzer onResult={handleAnalysisResult} />
                {result && <DocumentResult result={result} />}
                <UserDocuments 
                  documents={documents} 
                  onSelect={(doc) => setResult(doc.analysis_result)} 
                />
              </>
            ) : activeTab === 'profile' ? (
              <UserProfile 
                userId={selectedCustomerId || session.user.id}
                onUpdate={() => {
                  // Refresh data if needed
                }}
              />
            ) : activeTab === 'chat' && !isAgency && conversation ? (
              <ChatWindow
                conversation={conversation}
                onClose={() => setActiveTab('documents')}
              />
            ) : (
              <ResidencyProgress 
                progress={residencyProgress}
                isLoading={isLoadingProgress}
                onBackToCustomers={isAgency ? () => {
                  setSelectedCustomerId(null);
                  setSelectedCustomerEmail(null);
                  setActiveTab('customers');
                } : undefined}
                selectedCustomerId={selectedCustomerId}
              />
            )}
          </div>
        </div>
      </main>

      {!isAgency && activeTab !== 'chat' && <ChatButton />}
    </div>
  );
}