import React, { useState, useEffect } from 'react';
import { CheckCircle, Clock, AlertCircle, ArrowRight, Users, RefreshCw } from 'lucide-react';
import type { ResidencyProgress as ResidencyProgressType, ResidencyStep } from '../types';
import AgencyProgressControl from './AgencyProgressControl';
import { useAuth } from '../hooks/useAuth';
import { supabase, retryOperation } from '../lib/supabase';

interface Props {
  progress: ResidencyProgressType | null;
  isLoading: boolean;
  onBackToCustomers?: () => void;
  selectedCustomerId?: string | null;
}

// Translation mapping for step titles and descriptions
const stepTranslations: Record<string, { title: string; description: string }> = {
  'Subida de Documentos': {
    title: 'Document Upload',
    description: 'Initial submission and review of required documents in digital format'
  },
  'Traducción y Notarización': {
    title: 'Translation and Notarization',
    description: 'Official translation to Spanish and notarization of foreign documents'
  },
  'Cita en Migraciones': {
    title: 'Immigration Appointment',
    description: 'Physical document submission and interview at Immigration Office'
  },
  'Emisión de Residencia': {
    title: 'Residency Issuance',
    description: 'Processing and follow-up of application at Immigration Office'
  },
  'Tramitación de Cédula': {
    title: 'ID Card Processing',
    description: 'Processing of Paraguayan ID at the Identification Department'
  },
  'Recepción de Cédula': {
    title: 'ID Card Reception',
    description: 'Physical delivery of Paraguayan ID'
  },
  'Tramitación del RUC': {
    title: 'Tax ID Processing',
    description: 'Registration with Treasury to obtain Tax ID'
  },
  'Recepción del RUC': {
    title: 'Tax ID Reception',
    description: 'Delivery of official Tax ID document and process completion'
  }
};

// Helper function to translate step content
const translateStep = (step: ResidencyStep): ResidencyStep => {
  const translation = stepTranslations[step.title];
  if (!translation) return step;

  return {
    ...step,
    title: translation.title,
    description: translation.description
  };
};

export default function ResidencyProgress({ progress, isLoading, onBackToCustomers, selectedCustomerId }: Props) {
  const { session } = useAuth();
  const isAgency = session?.user?.user_metadata?.role === 'agency';
  const [localProgress, setLocalProgress] = useState<ResidencyProgressType | null>(progress);
  const [error, setError] = useState<string | null>(null);
  const [isRetrying, setIsRetrying] = useState(false);

  // Update local state when props change
  useEffect(() => {
    if (progress) {
      // Translate steps before setting local state
      setLocalProgress({
        ...progress,
        steps: progress.steps.map(translateStep)
      });
    } else {
      setLocalProgress(null);
    }
  }, [progress]);

  const getStepColor = (step: ResidencyStep) => {
    switch (step.status) {
      case 'completed':
        return 'bg-green-50 border-green-200';
      case 'in_progress':
        return 'bg-blue-50 border-blue-200';
      case 'blocked':
        return 'bg-red-50 border-red-200';
      default:
        return 'bg-gray-50 border-gray-200';
    }
  };

  const getStepIcon = (step: ResidencyStep) => {
    switch (step.status) {
      case 'completed':
        return <CheckCircle className="h-8 w-8 text-green-500" />;
      case 'in_progress':
        return <Clock className="h-8 w-8 text-blue-500" />;
      case 'blocked':
        return <AlertCircle className="h-8 w-8 text-red-500" />;
      default:
        return <Clock className="h-8 w-8 text-gray-300" />;
    }
  };

  const handleStepUpdate = async (stepId: string, status: string, notes: string) => {
    if (!localProgress) return;
    
    // Optimistically update the UI
    setLocalProgress(prev => {
      if (!prev) return null;
      return {
        ...prev,
        steps: prev.steps.map(step => 
          step.id === stepId 
            ? { ...step, status, notes, completedAt: status === 'completed' ? new Date().toISOString() : null }
            : step
        )
      };
    });
  };

  if (isLoading) {
    return (
      <div className="flex justify-center items-center p-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (!localProgress) {
    return (
      <div className="text-center py-12">
        <div className="bg-blue-50 inline-flex p-3 rounded-full">
          <Clock className="h-6 w-6 text-blue-600" />
        </div>
        <h3 className="mt-4 text-lg font-medium text-gray-900">No Active Process</h3>
        <p className="mt-2 text-sm text-gray-500">
          The residency process has not been started yet.
        </p>
      </div>
    );
  }

  const allCompleted = localProgress.steps.every(step => step.status === 'completed');
  const hasBlocked = localProgress.steps.some(step => step.status === 'blocked');

  return (
    <div className="bg-white rounded-lg shadow-lg p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-xl font-semibold text-gray-900">
            Residency Progress
          </h2>
          {isAgency && onBackToCustomers && (
            <button
              onClick={onBackToCustomers}
              className="mt-2 inline-flex items-center text-sm text-blue-600 hover:text-blue-500"
            >
              <Users className="h-4 w-4 mr-1" />
              Back to Customer List
            </button>
          )}
        </div>
        <span className={`px-3 py-1 rounded-full text-sm font-medium ${
          allCompleted ? 'bg-green-100 text-green-800' :
          hasBlocked ? 'bg-red-100 text-red-800' :
          'bg-blue-100 text-blue-800'
        }`}>
          {allCompleted ? 'Completed' :
           hasBlocked ? 'Blocked' :
           'In Progress'}
        </span>
      </div>

      <div className="space-y-4">
        {localProgress.steps.map((step, index) => (
          <div
            key={step.id}
            className={`relative p-6 rounded-lg border ${getStepColor(step)} transition-colors duration-200`}
          >
            <div className="flex items-start gap-4">
              {getStepIcon(step)}
              <div className="flex-1">
                <h3 className="text-lg font-medium text-gray-900">
                  {step.title}
                </h3>
                <p className="mt-1 text-sm text-gray-600">
                  {step.description}
                </p>
                {step.notes && (
                  <div className="mt-2 p-3 bg-white rounded-md text-sm text-gray-600">
                    {step.notes}
                  </div>
                )}
                {step.completedAt && (
                  <p className="mt-2 text-sm text-gray-500">
                    Completed: {new Date(step.completedAt).toLocaleDateString()}
                  </p>
                )}
                {isAgency && (
                  <AgencyProgressControl
                    progressId={localProgress.id}
                    step={step}
                    onUpdate={handleStepUpdate}
                  />
                )}
              </div>
            </div>
            {index < localProgress.steps.length - 1 && (
              <div className="absolute left-9 top-[5.5rem] bottom-0 w-px bg-gray-200" />
            )}
          </div>
        ))}
      </div>
    </div>
  );
}