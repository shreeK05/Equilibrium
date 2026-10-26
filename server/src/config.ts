const isProduction = process.env.NODE_ENV === 'production';
const jwtSecret = process.env.JWT_SECRET || (isProduction ? '' : 'test-secret');

if (isProduction && jwtSecret.length < 32) {
  throw new Error('JWT_SECRET must be set to at least 32 characters in production');
}

export const config = {
  jwtSecret,
  port: Number(process.env.PORT || 3000),
  resendApiKey: process.env.RESEND_API_KEY || 're_test',
  emailFrom: process.env.EMAIL_FROM || 'noreply@equilibrium.local',
  appPublicUrl: process.env.APP_PUBLIC_URL || process.env.RENDER_EXTERNAL_URL || 'https://equilibrium-42g8.onrender.com',
  groqApiKey: process.env.GROQ_API_KEY || '',
  groqModel: process.env.GROQ_MODEL || 'openai/gpt-oss-20b',
  groqFallbackModel: process.env.GROQ_FALLBACK_MODEL || 'llama-3.3-70b-versatile',
  groqTimeoutMs: Number(process.env.GROQ_TIMEOUT_MS || 8000),
  groqMaxTokens: Number(process.env.GROQ_MAX_TOKENS || 1024)
};
