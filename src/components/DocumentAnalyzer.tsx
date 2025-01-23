import React, { useState } from 'react';
import { Upload, Loader2, AlertCircle } from 'lucide-react';
import { analyzeDocument, uploadDocument } from '../utils/documentAnalysis';
import type { AnalysisResult } from '../types';
import { useAuth } from '../hooks/useAuth';

interface Props {
  onResult: (result: AnalysisResult & { file_path: string }) => void;
}

export default function DocumentAnalyzer({ onResult }: Props) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { session } = useAuth();

  const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file || !session?.user) return;

    setLoading(true);
    setError(null);

    try {
      // Validate file type before upload
      const allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
      if (!allowedTypes.includes(file.type)) {
        throw new Error('File type not allowed. Use JPG, PNG or WebP');
      }

      // First upload the file
      const filePath = await uploadDocument(file, session.user.id);
      
      // Then analyze the document
      const result = await analyzeDocument(file);
      
      // Pass both the result and file path to the parent
      onResult({ ...result, file_path: filePath });
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Error processing document';
      setError(errorMessage);
      console.error('Upload error:', err);
    } finally {
      setLoading(false);
      // Clear the input
      event.target.value = '';
    }
  };

  return (
    <div className="space-y-4">
      <div className="border-2 border-dashed border-gray-300 rounded-lg p-6">
        <div className="text-center">
          <Upload className="mx-auto h-12 w-12 text-gray-400" />
          <div className="mt-4">
            <label 
              htmlFor="file-upload" 
              className={`relative inline-flex items-center justify-center px-6 py-2 text-sm font-medium rounded-md
                ${loading 
                  ? 'bg-gray-100 text-gray-500 cursor-not-allowed' 
                  : 'bg-blue-50 text-blue-700 hover:bg-blue-100 cursor-pointer'}`}
            >
              <span className="relative">
                {loading ? 'Processing...' : 'Select document'}
              </span>
              <input
                id="file-upload"
                name="file-upload"
                type="file"
                className="sr-only"
                accept="image/jpeg,image/png,image/webp"
                onChange={handleFileUpload}
                disabled={loading}
                multiple={false}
                capture={false}
              />
            </label>
            <p className="mt-2 text-xs text-gray-500">
              PNG, JPG or WebP up to 10MB
            </p>
          </div>
          {loading && (
            <div className="mt-4 flex items-center justify-center gap-2 text-blue-600">
              <Loader2 className="h-5 w-5 animate-spin" />
              <span>Analyzing document...</span>
            </div>
          )}
          {error && (
            <div className="mt-4 p-3 bg-red-50 rounded-md">
              <div className="flex items-center gap-2 text-red-700">
                <AlertCircle className="h-5 w-5 flex-shrink-0" />
                <span className="text-sm font-medium">{error}</span>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}