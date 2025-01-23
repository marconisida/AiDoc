import React, { useState, useEffect } from 'react';
import { Download, FileText, Printer, AlertCircle } from 'lucide-react';
import { supabase, retryOperation } from '../lib/supabase';
import type { UserDocument } from '../types';

interface Props {
  document: UserDocument;
}

export function DocumentViewer({ document: userDocument }: Props) {
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [downloadUrl, setDownloadUrl] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [retryCount, setRetryCount] = useState(0);
  const MAX_RETRIES = 3;

  useEffect(() => {
    if (userDocument.file_path) {
      generateUrls();
    }
  }, [userDocument.file_path, retryCount]);

  const generateUrls = async () => {
    if (!userDocument.file_path) return;
    setError(null);
    setIsLoading(true);
    
    try {
      // Get public URL with retry
      const { data: publicUrlData, error: publicUrlError } = await retryOperation(() => 
        supabase.storage
          .from('documents')
          .getPublicUrl(userDocument.file_path)
      );

      if (publicUrlError) throw publicUrlError;
      if (!publicUrlData?.publicUrl) {
        throw new Error('Could not generate document URL');
      }

      // Verify the image is accessible
      const response = await fetch(publicUrlData.publicUrl, { method: 'HEAD' });
      if (!response.ok) {
        throw new Error('Could not access document');
      }

      // Create signed URL for download with retry
      const { data: signedData, error: signedError } = await retryOperation(() =>
        supabase.storage
          .from('documents')
          .createSignedUrl(userDocument.file_path, 3600, {
            download: true,
            transform: {
              quality: 80
            }
          })
      );

      if (signedError) throw signedError;
      if (!signedData?.signedUrl) {
        throw new Error('Could not generate download URL');
      }

      setPreviewUrl(publicUrlData.publicUrl);
      setDownloadUrl(signedData.signedUrl);
    } catch (error) {
      console.error('Error generating URLs:', error);
      setError('Error loading document. Please try again.');
      
      // Implement exponential backoff for retries
      if (retryCount < MAX_RETRIES) {
        const delay = Math.min(1000 * Math.pow(2, retryCount), 5000);
        setTimeout(() => {
          setRetryCount(prev => prev + 1);
        }, delay);
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleRetry = () => {
    setRetryCount(0);
    generateUrls();
  };

  const handleDownload = (e: React.MouseEvent) => {
    e.preventDefault();
    if (!downloadUrl) return;
    window.open(downloadUrl, '_blank');
  };

  const handlePrint = (e: React.MouseEvent) => {
    e.preventDefault();
    if (!previewUrl) return;
    
    const printWindow = window.open('', '_blank');
    if (!printWindow) return;

    printWindow.document.write(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>Print Document</title>
          <style>
            body { margin: 0; padding: 20px; }
            img { max-width: 100%; height: auto; }
          </style>
        </head>
        <body>
          <img src="${previewUrl}" alt="Document" />
        </body>
      </html>
    `);
    printWindow.document.close();
    printWindow.focus();
    printWindow.print();
  };

  return (
    <div className="bg-white p-4 rounded-lg shadow border border-gray-200">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <FileText className="h-5 w-5 text-blue-600" />
          <h3 className="font-medium text-gray-900">{userDocument.document_type}</h3>
        </div>
        <div className="flex gap-2">
          {downloadUrl && (
            <>
              <button
                onClick={handleDownload}
                className="inline-flex items-center gap-1 px-3 py-1.5 text-sm font-medium text-blue-700 bg-blue-50 rounded-md hover:bg-blue-100 transition-colors"
              >
                <Download className="h-4 w-4" />
                Download
              </button>
              <button
                onClick={handlePrint}
                className="inline-flex items-center gap-1 px-3 py-1.5 text-sm font-medium text-gray-700 bg-gray-50 rounded-md hover:bg-gray-100 transition-colors"
              >
                <Printer className="h-4 w-4" />
                Print
              </button>
            </>
          )}
        </div>
      </div>

      {previewUrl && !error && (
        <div className="mt-4 border rounded-lg overflow-hidden bg-gray-50">
          <img
            src={previewUrl}
            alt={userDocument.document_type}
            className="w-full h-auto max-h-96 object-contain"
            onError={() => setError('Error loading preview')}
          />
        </div>
      )}

      <div className="mt-2 text-sm text-gray-500">
        Uploaded on: {new Date(userDocument.created_at).toLocaleDateString()}
      </div>

      {error && (
        <div className="mt-2 p-4 bg-red-50 rounded-md">
          <div className="flex items-center gap-2 text-red-700 text-sm">
            <AlertCircle className="h-4 w-4 flex-shrink-0" />
            <div className="flex-1">{error}</div>
            <button
              onClick={handleRetry}
              className="px-3 py-1 text-xs font-medium text-red-700 hover:bg-red-100 rounded-md transition-colors"
            >
              Retry
            </button>
          </div>
        </div>
      )}

      {isLoading && (
        <div className="mt-2 flex items-center justify-center gap-2 text-gray-500">
          <div className="animate-spin h-4 w-4 border-2 border-blue-600 border-t-transparent rounded-full" />
          <span className="text-sm">Loading document...</span>
        </div>
      )}
    </div>
  );
}