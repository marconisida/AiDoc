import React, { useState, useEffect } from 'react';
import { supabase, retryOperation } from '../lib/supabase';
import { Search, User, Mail, Calendar, Trash2, AlertCircle, CheckCircle, Clock, XCircle } from 'lucide-react';

interface Customer {
  id: string;
  email: string;
  first_name: string | null;
  last_name: string | null;
  created_at: string;
  progress?: {
    status: string;
    current_step: number;
    total_steps: number;
    completed_steps: number;
    steps: Array<{
      status: string;
    }>;
  };
}

interface Props {
  onSelectCustomer: (userId: string, email: string) => void;
}

export default function AgencyCustomerList({ onSelectCustomer }: Props) {
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState<string | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [isDeleting, setIsDeleting] = useState(false);

  useEffect(() => {
    loadCustomers();
  }, []);

  const loadCustomers = async () => {
    try {
      // Get users with their profiles
      const { data: users, error: usersError } = await retryOperation(() =>
        supabase.rpc('get_users_with_profiles')
      );

      if (usersError) throw usersError;

      const nonAgencyUsers = users.filter(user => 
        user.raw_user_meta_data?.role !== 'agency'
      );

      // Get progress for all users with their steps
      const { data: progress, error: progressError } = await retryOperation(() =>
        supabase
          .from('residency_progress')
          .select(`
            user_id,
            status,
            current_step,
            residency_step_progress (
              status
            )
          `)
      );

      if (progressError) throw progressError;

      const customersWithProgress = nonAgencyUsers.map(user => {
        const userProgress = progress?.find(p => p.user_id === user.id);
        const totalSteps = userProgress?.residency_step_progress?.length || 0;
        const completedSteps = userProgress?.residency_step_progress?.filter(
          (step: any) => step.status === 'completed'
        ).length || 0;

        return {
          id: user.id,
          email: user.email,
          first_name: user.profile?.first_name,
          last_name: user.profile?.last_name,
          created_at: user.created_at,
          progress: userProgress ? {
            status: userProgress.status,
            current_step: userProgress.current_step,
            total_steps: totalSteps,
            completed_steps: completedSteps,
            steps: userProgress.residency_step_progress
          } : undefined
        };
      });

      setCustomers(customersWithProgress);
    } catch (error) {
      console.error('Error loading customers:', error);
    } finally {
      setIsLoading(false);
    }
  };

 const handleDeleteCustomer = async (customerId: string) => {
    try {
      setIsDeleting(true);
      setDeleteError(null);
      
      const { error } = await retryOperation(() =>
        supabase.rpc('delete_user', {
          user_id: customerId
        })
      );
      
      if (error) throw error;

      setCustomers(prev => prev.filter(c => c.id !== customerId));
      setShowDeleteConfirm(null);
    } catch (error) {
      console.error('Error deleting customer:', error);
      setDeleteError('Could not delete customer. Please try again.');
    } finally {
      setIsDeleting(false);
    }
  };

  const filteredCustomers = customers.filter(customer =>
    customer.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
    `${customer.first_name || ''} ${customer.last_name || ''}`
      .toLowerCase()
      .includes(searchTerm.toLowerCase())
  );

  const getProgressBadge = (progress?: Customer['progress']) => {
    if (!progress) {
      return {
        color: 'bg-gray-100 text-gray-800',
        text: `Step`,
        icon: <Clock className="h-4 w-4 text-gray-500" />
      };
    }

    const hasBlockedStep = progress.steps?.some(step => step.status === 'blocked');
    const allCompleted = progress.completed_steps === progress.total_steps;

    if (hasBlockedStep) {
      return {
        color: 'bg-red-100 text-red-800',
        text: `Step`,
        icon: <XCircle className="h-4 w-4 text-red-500" />
      };
    }

    if (allCompleted) {
      return {
        color: 'bg-green-100 text-green-800',
        text: 'Completed',
        icon: <CheckCircle className="h-4 w-4 text-green-500" />
      };
    }

    return {
      color: 'bg-blue-100 text-blue-800',
      text: `Step`,
      icon: <Clock className="h-4 w-4 text-blue-500" />
    };
  };

  const getProgressBarColor = (progress?: Customer['progress']) => {
    if (!progress) return 'bg-gray-200';
    
    const hasBlockedStep = progress.steps?.some(step => step.status === 'blocked');
    const allCompleted = progress.completed_steps === progress.total_steps;

    if (hasBlockedStep) return 'bg-red-500';
    if (allCompleted) return 'bg-green-500';
    return 'bg-blue-500';
  };

  if (isLoading) {
    return (
      <div className="flex justify-center items-center p-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg shadow">
      <div className="p-4 border-b">
        <div className="relative">
          <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <Search className="h-5 w-5 text-gray-400" />
          </div>
          <input
            type="text"
            placeholder="Search customer by email or name..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
          />
        </div>
      </div>

      {deleteError && (
        <div className="m-4 p-3 bg-red-50 rounded-md">
          <div className="flex items-center gap-2 text-red-700">
            <AlertCircle className="h-5 w-5 flex-shrink-0" />
            <span className="text-sm font-medium">{deleteError}</span>
          </div>
        </div>
      )}

      <div className="overflow-hidden">
        <ul role="list" className="divide-y divide-gray-200">
          {filteredCustomers.length === 0 ? (
            <li className="py-8">
              <div className="text-center">
                <User className="mx-auto h-12 w-12 text-gray-400" />
                <h3 className="mt-2 text-sm font-medium text-gray-900">
                  No customers found
                </h3>
                <p className="mt-1 text-sm text-gray-500">
                  {searchTerm ? 'Try different search terms' : 'No customers registered'}
                </p>
              </div>
            </li>
          ) : (
            filteredCustomers.map((customer) => {
              const badge = getProgressBadge(customer.progress);
              const progressPercent = customer.progress 
                ? (customer.progress.completed_steps / customer.progress.total_steps) * 100
                : 0;
              
              return (
                <li
                  key={customer.id}
                  className="hover:bg-gray-50"
                >
                  <div className="px-4 py-4 flex items-center justify-between">
                    <div 
                      className="min-w-0 flex-1 cursor-pointer"
                      onClick={() => onSelectCustomer(customer.id, customer.email)}
                    >
                      <div className="flex items-center">
                        <div className="bg-gray-100 rounded-full p-2">
                          <User className="h-5 w-5 text-gray-600" />
                        </div>
                        <div className="ml-4 flex-1">
                          <div className="flex items-center">
                            <Mail className="h-4 w-4 text-gray-400 mr-1" />
                            <p className="text-sm font-medium text-gray-900 truncate">
                              {customer.email}
                            </p>
                          </div>
                          {(customer.first_name || customer.last_name) && (
                            <p className="text-sm text-gray-500 mt-1">
                              {customer.first_name} {customer.last_name}
                            </p>
                          )}
                          <div className="flex items-center mt-1">
                            <Calendar className="h-4 w-4 text-gray-400 mr-1" />
                            <p className="text-sm text-gray-500">
                              Registered: {new Date(customer.created_at).toLocaleDateString()}
                            </p>
                          </div>
                          <div className="mt-2">
                            <div className="flex items-center gap-2 mb-1">
                              {badge.icon}
                              <span className={`text-xs font-medium ${badge.color} px-2 py-0.5 rounded-full`}>
                                {badge.text}
                              </span>
                              <span className="text-xs text-gray-500">
                                {customer.progress?.completed_steps || 0} of {customer.progress?.total_steps || 8} steps completed
                              </span>
                            </div>
                            <div className="w-full bg-gray-200 rounded-full h-1.5">
                              <div
                                className={`h-1.5 rounded-full transition-all duration-500 ${getProgressBarColor(customer.progress)}`}
                                style={{ width: `${progressPercent}%` }}
                              />
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                    <div className="ml-4">
                      {showDeleteConfirm === customer.id ? (
                        <div className="flex items-center gap-2">
                          <button
                            onClick={() => handleDeleteCustomer(customer.id)}
                            disabled={isDeleting}
                            className={`text-red-600 hover:text-red-800 text-sm font-medium ${
                              isDeleting ? 'opacity-50 cursor-not-allowed' : ''
                            }`}
                          >
                            {isDeleting ? 'Deleting...' : 'Confirm'}
                          </button>
                          <button
                            onClick={() => setShowDeleteConfirm(null)}
                            disabled={isDeleting}
                            className="text-gray-600 hover:text-gray-800 text-sm font-medium"
                          >
                            Cancel
                          </button>
                        </div>
                      ) : (
                        <button
                          onClick={() => setShowDeleteConfirm(customer.id)}
                          className="text-gray-400 hover:text-red-600 transition-colors"
                        >
                          <Trash2 className="h-5 w-5" />
                        </button>
                      )}
                    </div>
                  </div>
                </li>
              );
            })
          )}
        </ul>
      </div>
    </div>
  );
}