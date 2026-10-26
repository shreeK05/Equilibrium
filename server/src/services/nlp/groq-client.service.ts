import { config } from '../../config';

export interface GroqChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface GroqCompletionOptions {
  model?: string;
  temperature?: number;
  maxTokens?: number;
  timeoutMs?: number;
  userId?: string;
}

export interface GroqResponse<T = any> {
  success: boolean;
  data?: T;
  rawJson?: string;
  modelUsed?: string;
  durationMs: number;
  error?: {
    code: 'NOT_CONFIGURED' | 'RATE_LIMITED' | 'TIMEOUT' | 'AUTH_ERROR' | 'INVALID_JSON' | 'API_ERROR';
    message: string;
  };
}

export class GroqClientService {
  private readonly baseUrl = 'https://api.groq.com/openai/v1';
  private readonly userRequestTimestamps = new Map<string, number[]>();
  private readonly maxRequestsPerMinutePerUser = 10;

  /**
   * Whether Groq API key is present in environment
   */
  isConfigured(): boolean {
    return Boolean(config.groqApiKey && config.groqApiKey.trim().length > 0);
  }

  /**
   * Check per-user rate limit sliding window (prevents single user exhausting org quota)
   */
  private checkUserRateLimit(userId: string = 'global'): boolean {
    const now = Date.now();
    const windowStart = now - 60_000;
    const timestamps = this.userRequestTimestamps.get(userId) || [];
    const active = timestamps.filter(t => t > windowStart);

    if (active.length >= this.maxRequestsPerMinutePerUser) {
      this.userRequestTimestamps.set(userId, active);
      return false;
    }

    active.push(now);
    this.userRequestTimestamps.set(userId, active);
    return true;
  }

  /**
   * Verify if a specific model or Groq models list is available to the account
   */
  async verifyModelAvailable(modelName?: string): Promise<{ available: boolean; models: string[]; error?: string }> {
    if (!this.isConfigured()) {
      return { available: false, models: [], error: 'GROQ_API_KEY is not configured' };
    }

    const targetModel = modelName || config.groqModel;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 6000);

    try {
      const res = await fetch(`${this.baseUrl}/models`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${config.groqApiKey.trim()}`,
          'Content-Type': 'application/json'
        },
        signal: controller.signal
      });

      clearTimeout(timeout);

      if (!res.ok) {
        return {
          available: false,
          models: [],
          error: `Groq API responded with status ${res.status}`
        };
      }

      const body = await res.json() as { data?: Array<{ id: string }> };
      const models = (body.data || []).map(m => m.id);
      const isAvailable = models.includes(targetModel);

      return {
        available: isAvailable,
        models,
        error: isAvailable ? undefined : `Model '${targetModel}' not found in active account models`
      };
    } catch (err: any) {
      clearTimeout(timeout);
      return {
        available: false,
        models: [],
        error: err.name === 'AbortError' ? 'Models check timed out' : (err.message || 'Unknown network error')
      };
    }
  }

  /**
   * Execute chat completion requesting structured JSON output
   */
  async chatCompletionJson<T = any>(
    messages: GroqChatMessage[],
    options: GroqCompletionOptions = {}
  ): Promise<GroqResponse<T>> {
    const startTime = Date.now();

    if (!this.isConfigured()) {
      return {
        success: false,
        durationMs: 0,
        error: {
          code: 'NOT_CONFIGURED',
          message: 'GROQ_API_KEY environment variable is missing.'
        }
      };
    }

    const userId = options.userId || 'anonymous';
    if (!this.checkUserRateLimit(userId)) {
      return {
        success: false,
        durationMs: Date.now() - startTime,
        error: {
          code: 'RATE_LIMITED',
          message: 'Per-user request limit exceeded. Falling back to deterministic parsing.'
        }
      };
    }

    const model = options.model || config.groqModel;
    const timeoutMs = options.timeoutMs || config.groqTimeoutMs;
    const maxTokens = options.maxTokens || config.groqMaxTokens;
    const temperature = options.temperature ?? 0.1;

    // Truncate message contents to prevent giant prompt payloads
    const boundedMessages = messages.map(m => ({
      role: m.role,
      content: m.content.slice(0, 1500)
    }));

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const res = await fetch(`${this.baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${config.groqApiKey.trim()}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          model,
          messages: boundedMessages,
          temperature,
          max_tokens: maxTokens,
          response_format: { type: 'json_object' }
        }),
        signal: controller.signal
      });

      clearTimeout(timeoutId);
      const durationMs = Date.now() - startTime;

      if (!res.ok) {
        const statusCode = res.status;
        let errorMessage = `Groq HTTP ${statusCode}`;
        try {
          const errBody = await res.json() as any;
          if (errBody?.error?.message) {
            errorMessage = errBody.error.message;
          }
        } catch (_) {}

        if (statusCode === 401 || statusCode === 403) {
          return {
            success: false,
            durationMs,
            error: { code: 'AUTH_ERROR', message: `Authentication error: ${errorMessage}` }
          };
        }
        if (statusCode === 429) {
          return {
            success: false,
            durationMs,
            error: { code: 'RATE_LIMITED', message: `Groq rate limit reached: ${errorMessage}` }
          };
        }
        return {
          success: false,
          durationMs,
          error: { code: 'API_ERROR', message: errorMessage }
        };
      }

      const body = await res.json() as any;
      const content = body.choices?.[0]?.message?.content;
      if (!content) {
        return {
          success: false,
          durationMs,
          error: { code: 'INVALID_JSON', message: 'No content returned from model.' }
        };
      }

      try {
        const parsed = JSON.parse(content) as T;
        return {
          success: true,
          data: parsed,
          rawJson: content,
          modelUsed: model,
          durationMs
        };
      } catch (parseErr) {
        return {
          success: false,
          rawJson: content,
          durationMs,
          error: { code: 'INVALID_JSON', message: 'Model output could not be parsed as JSON.' }
        };
      }
    } catch (err: any) {
      clearTimeout(timeoutId);
      const durationMs = Date.now() - startTime;
      if (err.name === 'AbortError') {
        return {
          success: false,
          durationMs,
          error: { code: 'TIMEOUT', message: `Groq request timed out after ${timeoutMs}ms.` }
        };
      }
      return {
        success: false,
        durationMs,
        error: { code: 'API_ERROR', message: err.message || 'Unknown network error' }
      };
    }
  }
}

export const groqClient = new GroqClientService();
