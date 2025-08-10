import { Part } from "@google/genai";
import { PerceptionPlan, RegulatorReport } from "../types";
import { LITELLM_BASE_URL } from '../constants';

// Helper to safely parse JSON from a model response, stripping markdown fences.
export const parseJsonFromMarkdown = <T>(jsonString: string): T | null => {
    let cleanedString = jsonString.trim();
    const fenceRegex = /^```(\w*)?\s*\n?(.*?)\n?\s*```$/s;
    const match = cleanedString.match(fenceRegex);

    if (match && match[2]) {
        cleanedString = match[2].trim();
    }

    try {
        return JSON.parse(cleanedString);
    } catch (e) {
        console.error("Failed to parse JSON response:", e, "\nOriginal string:", jsonString);
        return null;
    }
};

// Helper to handle API errors from fetch response
const getApiError = async (response: Response): Promise<string> => {
    try {
        const errorBody = await response.json();
        return errorBody?.error?.message || `API request failed with status ${response.status}`;
    } catch (e) {
        return `API request failed with status ${response.status}`;
    }
};

interface LiteLLMUsage {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
}

interface JsonApiResponse {
    data: PerceptionPlan | RegulatorReport | null;
    error?: string;
    usage?: LiteLLMUsage;
}

// New function for getting a structured JSON response (for Stage 1 & Regulator)
export const callLiteLLMApiForJson = async <T>(
  prompt: string,
  model: string,
  temperature: number,
  apiKey: string,
  systemInstruction?: string,
): Promise<{ data: T | null; error?: string; usage?: LiteLLMUsage; }> => {
  if (!apiKey) {
    const errorMsg = "API Key not provided for JSON API call.";
    console.error(errorMsg);
    return { data: null, error: errorMsg };
  }
  
  const messages = [];
  if(systemInstruction) {
    messages.push({ role: 'system', content: systemInstruction });
  }
  messages.push({ role: 'user', content: prompt });

  try {
    const response = await fetch(`${LITELLM_BASE_URL}/chat/completions`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${apiKey}`
        },
        body: JSON.stringify({
            model: model,
            messages: messages,
            temperature: temperature,
            response_format: { type: "json_object" },
            stream: false
        }),
    });

    if (!response.ok) {
        const error = await getApiError(response);
        console.error("Error calling LiteLLM API for JSON:", error, response);
        return { data: null, error };
    }

    const responseData = await response.json();
    const content = responseData.choices?.[0]?.message?.content;
    const usage = responseData.usage;
    
    if (!content) {
        const errorReason = "Model returned an empty response content.";
        console.error("Error calling LiteLLM API for JSON:", errorReason, responseData);
        return { data: null, error: errorReason, usage };
    }
    
    const parsedData = parseJsonFromMarkdown<T>(content);

    if (!parsedData) {
        return { data: null, error: "Failed to parse valid JSON from model response.", usage };
    }

    return { data: parsedData, usage };

  } catch (error: any) {
    console.error("Error calling LiteLLM API for JSON:", error);
    const errorMessage = error.message || String(error);
    return { data: null, error: `LiteLLM API Error: ${errorMessage}` };
  }
};


export const callLiteLLMAPIStream = async (
  promptContent: string | Part | (string | Part)[],
  model: string,
  temperature: number,
  apiKey: string,
  onStreamChunk: (chunkText: string, isFinal: boolean) => void,
  onError: (errorMessage: string) => void,
  onUsage: (usage: LiteLLMUsage) => void,
  systemInstruction?: string
): Promise<void> => {
  if (!apiKey) {
    const errorMsg = "API Key not provided for streaming.";
    console.error(errorMsg);
    onError(errorMsg);
    return;
  }

  const messages = [];
  if (systemInstruction) {
      messages.push({ role: 'system', content: systemInstruction });
  }
  const prompt = typeof promptContent === 'string' ? promptContent : JSON.stringify(promptContent);
  messages.push({ role: 'user', content: prompt });

  try {
    const response = await fetch(`${LITELLM_BASE_URL}/chat/completions`, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            model: model,
            messages: messages,
            temperature: temperature,
            stream: true,
            stream_options: { "include_usage": true } // Request usage data
        }),
    });

    if (!response.ok || !response.body) {
        const error = await getApiError(response);
        console.error("Error calling LiteLLM API (stream):", error);
        onError(error);
        return;
    }
    
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
            if (line.trim() === '' || !line.startsWith('data: ')) continue;
            
            const data = line.substring(6).trim();

            if (data === '[DONE]') {
                onStreamChunk("", true);
                return;
            }

            try {
                const parsed = JSON.parse(data);
                if (parsed.usage) {
                    onUsage(parsed.usage);
                    continue; // This is a usage chunk, not a text chunk.
                }

                const chunkText = parsed.choices?.[0]?.delta?.content || '';
                if(chunkText) {
                    onStreamChunk(chunkText, false);
                }
            } catch (e) {
                console.error("Failed to parse stream chunk:", e, "Chunk:", data);
            }
        }
    }
    
    onStreamChunk("", true);

  } catch (error: any) {
    console.error("Error calling LiteLLM API (stream):", error);
    let errorMessage = "An unknown error occurred with the LiteLLM API stream.";
     if (error.message) {
      errorMessage = error.message;
    } else if (typeof error === 'string') {
      errorMessage = error;
    }
    onError(`LiteLLM API Stream Error: ${errorMessage}`);
  }
};
