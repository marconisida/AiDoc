// Google Cloud Vision API configuration
export const VISION_CONFIG = {
  apiKey: 'your_api_key_here',
  baseURL: 'https://vision.googleapis.com/v1'
};

// Initialize Vision client with credentials
export function initVisionClient() {
  return {
    credentials: {
      client_email: 'document-analyzer@your-project.iam.gserviceaccount.com',
      private_key: process.env.GOOGLE_CLOUD_PRIVATE_KEY
    }
  };
}