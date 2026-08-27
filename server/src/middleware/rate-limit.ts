import rateLimit from 'express-rate-limit';

// Prevent trivial brute force attacks on Auth endpoints
export const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20, // limit each IP to 20 requests per windowMs for auth routes
  message: { error: { code: 'RATE_LIMIT_EXCEEDED', message: 'Too many authentication attempts, please try again later.' } },
  standardHeaders: true,
  legacyHeaders: false,
});
