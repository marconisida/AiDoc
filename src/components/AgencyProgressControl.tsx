import React, { useState, useEffect } from 'react';
import { CheckCircle, MessageCircle, Save } from 'lucide-react';
import { supabase, retryOperation } from '../lib/supabase';
import type { ResidencyStep } from '../types';

interface Props {
  progressId: string;
  step: ResidencyStep;
  onUpdate: (stepId: string, status: string, notes: string) => void;
}

export default function AgencyProgressControl({ progressId, step, onUpdate }: Props) {
  const [status, setStatus] = useState(step.status);
  const [notes, setNotes] = useState(step.notes || '');
  const [isUpdating, setIsUpdating] = useState(false);

  // Keep local state in sync with props
  useEffect(() => {
    setStatus(step.status);
    setNotes(step.notes || '');
  }, [step]);

  const handleUpdateProgress = async () => {
    setIsUpdating(true);

    try {
      // First update the step progress
      const { error: updateError } = await retryOperation(() =>
        supabase
          .from('residency_step_progress')
          .update({
            status,
            notes,
            completed_at: status === 'completed' ? new Date().toISOString() : null
          })
          .eq('progress_id', progressId)
          .eq('step_id', step.id)
      );

      if (updateError) throw updateError;

      // Then update the overall progress status if needed
      if (status === 'blocked') {
        const { error: progressError } = await retryOperation(() =>
          supabase
            .from('residency_progress')
            .update({ status: 'blocked' })
            .eq('id', progressId)
        );

        if (progressError) throw progressError;
      }

      // Notify parent component for optimistic update
      onUpdate(step.id, status, notes);
    } catch (error) {
      console.error('Error updating progress:', error);
      // Revert local state on error
      setStatus(step.status);
      setNotes(step.notes || '');
    } finally {
      setIsUpdating(false);
    }
  };

  return (
    <div className="mt-4 space-y-4 border-t pt-4">
      <div className="flex items-center gap-4">
        <label className="text-sm font-medium text-gray-700">Status:</label>
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value as ResidencyStep['status'])}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
          disabled={isUpdating}
        >
          <option value="pending">Pending</option>
          <option value="in_progress">In Progress</option>
          <option value="completed">Completed</option>
          <option value="blocked">Blocked</option>
        </select>
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">
          <MessageCircle className="inline-block h-4 w-4 mr-1" />
          Notes for customer:
        </label>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          rows={3}
          disabled={isUpdating}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
          placeholder="Add notes or comments about this step..."
        />
      </div>

      <button
        onClick={handleUpdateProgress}
        disabled={isUpdating}
        className={`inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white transition-colors
          ${isUpdating 
            ? 'bg-gray-400 cursor-not-allowed' 
            : 'bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500'
          }`}
      >
        {isUpdating ? (
          <>
            <div className="animate-spin mr-2 h-4 w-4 border-2 border-white border-t-transparent rounded-full"></div>
            Updating...
          </>
        ) : (
          <>
            <Save className="h-4 w-4 mr-2" />
            Save Changes
          </>
        )}
      </button>
    </div>
  );
}