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
  const token = req.query.token;
  if (!token) {
    return res.status(400).send('Invalid token');
  }
  // This simple HTML page redirects the browser to the Flutter app via a custom scheme deep link.
  res.send(`
    <html>
      <head><title>Resetting Password...</title></head>
      <body>
        <p>Redirecting to the Equilibrium app...</p>
        <script>
          window.location.href = "equilibrium://reset-password?token=${token}";
        </script>
      </body>
    </html>
  `);
});
