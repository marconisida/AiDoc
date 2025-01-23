import { OPENAI_CONFIG } from '../config/openai';
import type { ChatMessage } from '../types';

interface BotResponse {
  content: string;
  confidence: number;
}

export async function getBotResponse(messages: ChatMessage[]): Promise<BotResponse> {
  try {
    const prompt = `Eres un asistente experto en trámites de residencia en Paraguay. Responde de manera concisa y profesional.

Historial de la conversación:
${messages.map(m => `${m.sender_type}: ${m.content}`).join('\n')}

Instrucciones:
1. Responde en español
2. Sé conciso y directo
3. Si no estás seguro, deriva al agente humano
4. No inventes información sobre trámites

Responde en formato JSON:
{
  "content": "tu respuesta",
  "confidence": número entre 0 y 1 indicando tu confianza en la respuesta
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
            content: 'Eres un asistente especializado en trámites de residencia en Paraguay.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.7,
        response_format: { type: 'json_object' }
      })
    });

    if (!response.ok) {
      throw new Error('Error en el servicio de IA');
    }

    const result = await response.json();
    return JSON.parse(result.choices[0].message.content);
  } catch (error) {
    console.error('Bot response error:', error);
    return {
      content: 'Lo siento, estoy teniendo problemas técnicos. Por favor, espere a que un agente humano lo atienda.',
      confidence: 0
    };
  }
}