import { supabase } from '../lib/supabase';
import type { AnalysisResult, DocumentType } from '../types';
import { VISION_CONFIG } from '../config/vision';
import { OPENAI_CONFIG } from '../config/openai';

// Function to call Vision API
async function callVisionAPI(imageData: string) {
  try {
    const response = await fetch(`${VISION_CONFIG.baseURL}/images:annotate?key=${VISION_CONFIG.apiKey}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        requests: [{
          image: {
            content: imageData.split(',')[1]
          },
          features: [
            { type: 'TEXT_DETECTION' },
            { type: 'DOCUMENT_TEXT_DETECTION' },
            { type: 'FACE_DETECTION' }
          ]
        }]
      })
    });

    if (!response.ok) {
      throw new Error('Error in Vision API service');
    }

    return response.json();
  } catch (error) {
    console.error('Vision API error:', error);
    throw new Error('Error processing document image');
  }
}

async function detectLanguage(text: string): Promise<{
  isSpanish: boolean;
  detectedLanguage: string;
  confidence: number;
}> {
  try {
    const prompt = `Analyze the following text and determine its main language. IGNORE proper names, places, dates and numbers.

Text from document:
"""
${text}
"""

IMPORTANT INSTRUCTIONS:
1. Analyze the complete text, paying special attention to:
   - Function words (articles, prepositions, conjunctions)
   - Administrative and bureaucratic terms
   - Grammar structure and syntax

2. COMPLETELY IGNORE:
   - People's proper names
   - Place and country names
   - Dates and numbers
   - Official seals
   - Signatures and titles

Respond in JSON format:
{
  "isSpanish": boolean (true if text is mainly in Spanish),
  "detectedLanguage": string (name of main detected language),
  "confidence": number (0-1, confidence level in detection)
}`;

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${OPENAI_CONFIG.apiKey}`
      },
      body: JSON.stringify({
        model: OPENAI_CONFIG.model,
        messages: [
          {
            role: 'system',
            content: 'You are a linguistic expert specialized in identifying languages in official documents.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.1,
        response_format: { type: 'json_object' }
      })
    });

    if (!response.ok) {
      throw new Error('Error in language detection service');
    }

    const result = await response.json();
    return JSON.parse(result.choices[0].message.content);
  } catch (error) {
    console.error('Language detection error:', error);
    throw new Error('Error detecting document language');
  }
}

async function classifyDocumentType(text: string, hasFaces: boolean): Promise<{
  documentType: DocumentType;
  country: string;
  confidence: number;
}> {
  try {
    const prompt = `Classify the following document based on its content. The document ${hasFaces ? 'contains' : 'does not contain'} a face photo.

Text from document:
"""
${text}
"""

Valid document types:
- Passport
- Identity Document
- Birth Certificate
- Marriage Certificate
- Criminal Record Certificate
- Interpol Certificate
- Residency Card
- Entry Permit

Respond in JSON format:
{
  "documentType": "document type from the list above",
  "country": "document's country of origin",
  "confidence": "number between 0 and 1 indicating classification confidence"
}`;

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${OPENAI_CONFIG.apiKey}`
      },
      body: JSON.stringify({
        model: OPENAI_CONFIG.model,
        messages: [
          {
            role: 'system',
            content: 'You are an expert in official documentation.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.1,
        response_format: { type: 'json_object' }
      })
    });

    if (!response.ok) {
      throw new Error('Error in document classification service');
    }

    const result = await response.json();
    return JSON.parse(result.choices[0].message.content);
  } catch (error) {
    console.error('Document classification error:', error);
    throw new Error('Error classifying document type');
  }
}

function getDocumentRequirements(documentType: DocumentType, isSpanish: boolean) {
  if (documentType === 'Passport' || documentType === 'Identity Document' || documentType === 'Residency Card') {
    return {
      apostille: { 
        isRequired: false, 
        description: 'No apostille or legalization required' 
      },
      translation: { 
        isRequired: false, 
        description: 'No translation required' 
      },
      validity: { 
        isRequired: true, 
        description: 'Minimum 6 months validity', 
        validityPeriod: '6 months' 
      }
    };
  }

  return {
    apostille: { 
      isRequired: true, 
      description: 'Requires mandatory apostille or legalization' 
    },
    translation: { 
      isRequired: !isSpanish, 
      description: isSpanish ? 'No translation required (document in Spanish)' : 'Requires translation to Spanish' 
    },
    validity: { 
      isRequired: documentType === 'Criminal Record Certificate', 
      description: documentType === 'Criminal Record Certificate' 
        ? 'Maximum validity of 6 months' 
        : 'No validity period',
      validityPeriod: documentType === 'Criminal Record Certificate' ? '6 months' : undefined
    }
  };
}

export async function analyzeDocument(file: File): Promise<AnalysisResult> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    
    reader.onload = async (e) => {
      try {
        const imageData = e.target?.result as string;
        const visionResponse = await callVisionAPI(imageData);
        
        const text = visionResponse.responses[0]?.fullTextAnnotation?.text || '';
        const hasFaces = visionResponse.responses[0]?.faceAnnotations?.length > 0;
        
        const languageInfo = await detectLanguage(text);
        const classification = await classifyDocumentType(text, hasFaces);
        const requirements = getDocumentRequirements(classification.documentType, languageInfo.isSpanish);

        resolve({
          documentType: classification.documentType,
          country: classification.country,
          isApostilled: text.toLowerCase().includes('apostill'),
          status: 'review',
          condition: 'Document under analysis',
          observations: [
            `Detected language: ${languageInfo.detectedLanguage}`,
            'Verify data authenticity',
            'Ensure data matches other submitted documents',
            'Confirm document meets specific requirements for Paraguay'
          ],
          requirements,
          validityPeriod: requirements.validity.validityPeriod
        });
      } catch (error) {
        reject(error);
      }
    };
    
    reader.onerror = () => {
      reject(new Error('Error reading file'));
    };
    
    reader.readAsDataURL(file);
  });
}

export async function uploadDocument(file: File, userId: string): Promise<string> {
  if (!file || !userId) {
    throw new Error('File and user are required');
  }

  if (file.size > 10 * 1024 * 1024) {
    throw new Error('File must not exceed 10MB');
  }

  // Only allow image formats
  const allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
  if (!allowedTypes.includes(file.type)) {
    throw new Error('File type not allowed. Use JPG, PNG or WebP');
  }

  try {
    // Create a clean file path with proper extension
    const fileExt = file.type.split('/')[1];
    const cleanFileName = `${Date.now()}-${Math.random().toString(36).substring(2)}.${fileExt}`;
    const filePath = `${userId}/${cleanFileName}`;

    // Create a blob with the correct content type
    const blob = new Blob([await file.arrayBuffer()], { type: file.type });

    // Upload file with explicit content type
    const { data, error: uploadError } = await supabase.storage
      .from('documents')
      .upload(filePath, blob, {
        contentType: file.type,
        duplex: 'half',
        upsert: false
      });

    if (uploadError) {
      console.error('Upload error:', uploadError);
      throw new Error(uploadError.message);
    }

    if (!data?.path) {
      throw new Error('Error getting document path');
    }

    // Verify the upload by getting the URL
    const { data: urlData } = supabase.storage
      .from('documents')
      .getPublicUrl(data.path);

    if (!urlData?.publicUrl) {
      throw new Error('Error generating document URL');
    }

    // Verify the file is accessible
    const response = await fetch(urlData.publicUrl, { method: 'HEAD' });
    if (!response.ok || !response.headers.get('content-type')?.startsWith('image/')) {
      throw new Error('Error verifying uploaded file');
    }

    return data.path;
  } catch (error) {
    console.error('Document upload error:', error);
    throw error instanceof Error ? error : new Error('Error uploading document');
  }
}