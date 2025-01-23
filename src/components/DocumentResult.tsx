import React from 'react';
import { CheckCircle, XCircle, AlertTriangle, Calendar, FileCheck, Languages } from 'lucide-react';
import type { AnalysisResult } from '../types';

interface Props {
  result: AnalysisResult;
}

export default function DocumentResult({ result }: Props) {
  // Function to determine if everything is in order
  const isDocumentValid = () => {
    const { requirements, documentType } = result;
    
    // For passports and identity documents we only verify validity
    if (documentType === 'Passport' || documentType === 'Identity Document' || documentType === 'Residency Card') {
      return true; // These documents don't need apostille or translation
    }

    // For certificates, verify apostille and translation if needed
    const hasRequiredApostille = !requirements.apostille.isRequired || result.isApostilled;
    const hasRequiredTranslation = !requirements.translation.isRequired || result.isApostilled;

    return hasRequiredApostille && hasRequiredTranslation;
  };

  const getStatusIcon = () => {
    if (isDocumentValid()) {
      return <CheckCircle className="h-8 w-8 text-green-500" />;
    }
    switch (result.status) {
      case 'valid':
        return <CheckCircle className="h-8 w-8 text-green-500" />;
      case 'invalid':
        return <XCircle className="h-8 w-8 text-red-500" />;
      default:
        return <AlertTriangle className="h-8 w-8 text-yellow-500" />;
    }
  };

  const getStatusColor = () => {
    if (isDocumentValid()) {
      return 'bg-green-50 border-green-200';
    }
    switch (result.status) {
      case 'valid':
        return 'bg-green-50 border-green-200';
      case 'invalid':
        return 'bg-red-50 border-red-200';
      default:
        return 'bg-yellow-50 border-yellow-200';
    }
  };

  return (
    <div className={`mt-6 p-6 rounded-lg border ${getStatusColor()}`}>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex items-start gap-4">
          {getStatusIcon()}
          <div className="flex-1">
            <h3 className="text-xl font-semibold">{result.documentType}</h3>
            <p className="text-gray-600">Country of origin: {result.country}</p>
          </div>
        </div>

        {/* Requirements */}
        <div className="grid gap-4 md:grid-cols-3">
          <div className={`p-4 bg-white rounded-lg border ${result.requirements.apostille.isRequired && !result.isApostilled ? 'border-yellow-300' : 'border-gray-200'}`}>
            <div className="flex items-center gap-2 mb-2">
              <FileCheck className={`h-5 w-5 ${result.requirements.apostille.isRequired && !result.isApostilled ? 'text-yellow-500' : 'text-blue-500'}`} />
              <h4 className="font-medium">Apostille</h4>
            </div>
            <p className="text-sm text-gray-600">{result.requirements.apostille.description}</p>
            {result.apostilleDate && (
              <p className="text-sm text-gray-500 mt-1">Date: {result.apostilleDate}</p>
            )}
          </div>

          <div className={`p-4 bg-white rounded-lg border ${result.requirements.translation.isRequired ? 'border-yellow-300' : 'border-gray-200'}`}>
            <div className="flex items-center gap-2 mb-2">
              <Languages className={`h-5 w-5 ${result.requirements.translation.isRequired ? 'text-yellow-500' : 'text-blue-500'}`} />
              <h4 className="font-medium">Translation</h4>
            </div>
            <p className="text-sm text-gray-600">{result.requirements.translation.description}</p>
          </div>

          <div className={`p-4 bg-white rounded-lg border ${result.requirements.validity.isRequired ? 'border-yellow-300' : 'border-gray-200'}`}>
            <div className="flex items-center gap-2 mb-2">
              <Calendar className={`h-5 w-5 ${result.requirements.validity.isRequired ? 'text-yellow-500' : 'text-blue-500'}`} />
              <h4 className="font-medium">Validity</h4>
            </div>
            <p className="text-sm text-gray-600">{result.requirements.validity.description}</p>
            {result.validityPeriod && (
              <p className="text-sm text-gray-500 mt-1">Period: {result.validityPeriod}</p>
            )}
          </div>
        </div>

        {/* Observations */}
        <div className="bg-white p-4 rounded-lg border border-gray-200">
          <h4 className="font-medium mb-2">Important observations:</h4>
          <ul className="space-y-2">
            {result.observations.map((observation, index) => (
              <li key={index} className="flex items-start gap-2 text-sm">
                <span className="text-blue-500 mt-1">•</span>
                <span>{observation}</span>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </div>
  );
}