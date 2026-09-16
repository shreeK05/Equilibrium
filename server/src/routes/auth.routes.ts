import { Router } from 'express';
import { authService } from '../services/auth.service';
import { registerSchema } from '../validation/schemas';
import { validate } from '../middleware/validate';
import { authRateLimiter } from '../middleware/rate-limit';
import { z } from 'zod';
import { authenticate } from '../middleware/auth';
import { userRepo } from '../repositories/user.repo';

const forgotPasswordSchema = z.object({
  email: z.string().email().toLowerCase(),
});

const resetPasswordSchema = z.object({
  token: z.string(),
  newPassword: z.string().min(8),
});

export const authRouter = Router();

authRouter.use(authRateLimiter);

authRouter.post('/register', validate(registerSchema), async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const result = await authService.register(email, password);
    res.json(result);
  } catch (err: any) {
    if (err.message === 'Email in use') return res.status(409).json({ error: { message: err.message } });
    next(err);
  }
});

authRouter.post('/login', validate(registerSchema), async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const result = await authService.login(email, password);
    res.json(result);
  } catch (err: any) {
    if (err.message === 'Invalid credentials') {
      return res.status(401).json({ error: { code: 'INVALID_CREDENTIALS', message: 'Invalid email or password.' } });
    }
    next(err);
  }
});

authRouter.post('/forgot-password', validate(forgotPasswordSchema), async (req, res, next) => {
  try {
    const { email } = req.body;
    await authService.forgotPassword(email);
    // Generic response regardless of existence
    res.json({ message: "If an account exists for this email, we've sent password reset instructions." });
  } catch (err) {
    next(err);
  }
});

authRouter.post('/reset-password', validate(resetPasswordSchema), async (req, res, next) => {
  try {
    const { token, newPassword } = req.body;
    await authService.resetPassword(token, newPassword);
    res.json({ message: 'Password has been successfully reset.' });
  } catch (err: any) {
    if (err.message === 'Invalid or expired reset token') {
      return res.status(400).json({ error: { code: 'INVALID_TOKEN', message: err.message } });
    }
    next(err);
  }
});

authRouter.get('/me', authenticate, async (req: any, res, next) => {
  try {
    const user = await userRepo.findById(req.userId);
    if (!user) return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'User not found' } });
    res.json({ id: user.id, email: user.email, timezone: user.timezone, createdAt: user.createdAt });
  } catch (err) { next(err); }
});

authRouter.get('/reset-redirect', (req, res) => {
  const token = req.query.token as string;
  if (!token) {
    return res.status(400).send('Invalid token');
  }

  const escapeHtml = (unsafe: string) => {
    return unsafe
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  };

  const escapedToken = escapeHtml(token);

  // Serve a mobile-friendly page with a manual button to launch the custom scheme.
  res.send(`
    <!DOCTYPE html>
    <html>
      <head>
        <title>Resetting Password...</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; background-color: #f9fafb; color: #111827; }
          .container { text-align: center; padding: 2rem; background: white; border-radius: 8px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1); max-width: 90%; }
          h1 { margin-top: 0; color: #4f46e5; font-size: 1.5rem; }
          h2 { font-size: 1.25rem; margin-bottom: 0.5rem; }
          p { margin: 0.5rem 0; color: #4b5563; }
          a.button { display: inline-block; margin-top: 1.5rem; padding: 0.75rem 1.5rem; background-color: #4f46e5; color: white; text-decoration: none; border-radius: 0.375rem; font-weight: 600; }
          a.button:hover { background-color: #4338ca; }
          .fallback { margin-top: 1.5rem; font-size: 0.875rem; color: #6b7280; }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>Equilibrium</h1>
          <h2>Reset your password</h2>
          <p>Tap the button below to open the Equilibrium app and securely reset your password.</p>
          <a class="button" href="equilibrium://reset-password?token=${escapedToken}">Open Equilibrium</a>
          <p class="fallback">If the app does not open, make sure Equilibrium is installed.</p>
        </div>
      </body>
    </html>
  `);
});
