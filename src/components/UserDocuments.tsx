import React from 'react';
import { FileCheck, Clock, CheckCircle, AlertTriangle } from 'lucide-react';
import type { UserDocument } from '../types';
import { DocumentViewer } from './DocumentViewer';

interface Props {
  documents: UserDocument[];
  onSelect: (document: UserDocument) => void;
}

export default function UserDocuments({ documents, onSelect }: Props) {
  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'valid':
        return <CheckCircle className="h-5 w-5 text-green-500" />;
      case 'invalid':
        return <AlertTriangle className="h-5 w-5 text-red-500" />;
      default:
        return <Clock className="h-5 w-5 text-yellow-500" />;
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-lg p-6 mt-6">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-semibold text-gray-900">My Documents</h2>
        <span className="text-sm text-gray-500">
          Total: {documents.length} documents
        </span>
      </div>

      <div className="space-y-4">
        {documents.length === 0 ? (
          <div className="text-center py-8">
            <FileCheck className="h-12 w-12 text-gray-400 mx-auto mb-3" />
            <p className="text-gray-500">No documents analyzed yet</p>
          </div>
        ) : (
          documents.map((doc) => (
            <div key={doc.id} className="space-y-4">
              <div
                onClick={() => onSelect(doc)}
                className="flex items-center p-4 border rounded-lg hover:bg-gray-50 cursor-pointer transition-colors"
              >
                <div className="flex-shrink-0">
                  {getStatusIcon(doc.analysis_result.status)}
                </div>
                <div className="ml-4 flex-1">
                  <h3 className="text-sm font-medium text-gray-900">
                    {doc.document_type}
                  </h3>
                  <p className="text-sm text-gray-500">
                    Country: {doc.analysis_result.country}
                  </p>
                </div>
                <div className="text-right text-sm text-gray-500">
                  {new Date(doc.created_at).toLocaleDateString()}
                </div>
              </div>
              <DocumentViewer document={doc} />
            </div>
          ))
        )}
      </div>
    </div>
  );
}