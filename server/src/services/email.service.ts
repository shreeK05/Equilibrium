import { Resend } from 'resend';
import { config } from '../config';

export interface SentEmailRecord {
  to: string;
  from: string;
  subject: string;
  otp?: string;
  html: string;
  sentAt: Date;
}

export class EmailService {
  private resendClient: Resend | null = null;
  private testMailbox: SentEmailRecord[] = [];

  constructor() {
    if (this.isConfigured()) {
      this.resendClient = new Resend(config.resendApiKey.trim());
    }
  }

  /**
   * Check if Resend API key is properly configured
   */
  isConfigured(): boolean {
    const key = (config.resendApiKey || '').trim();
    return Boolean(key && key !== 're_test' && key.startsWith('re_'));
  }

  /**
   * Access in-memory test mailbox for unit/integration tests
   */
  getTestMailbox(): SentEmailRecord[] {
    return [...this.testMailbox];
  }

  /**
   * Clear test mailbox between tests
   */
  clearTestMailbox(): void {
    this.testMailbox = [];
  }

  /**
   * Get latest OTP sent to a specific email in test environment
   */
  getLatestOtpForEmail(email: string): string | undefined {
    const match = [...this.testMailbox]
      .reverse()
      .find(m => m.to.toLowerCase() === email.toLowerCase());
    return match?.otp;
  }

  /**
   * Send 6-digit OTP email for account registration
   */
  async sendRegistrationOtp(
    email: string,
    otp: string,
    name?: string
  ): Promise<{ success: boolean; error?: string }> {
    const fromAddress = config.emailFrom.includes('@')
      ? config.emailFrom
      : 'onboarding@resend.dev';
    const sender = `Equilibrium <${fromAddress}>`;
    const subject = `${otp} is your Equilibrium verification code`;
    const greeting = name ? `Hi ${name},` : 'Welcome to Equilibrium,';

    const html = `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 560px; margin: 0 auto; padding: 32px 24px; background-color: #ffffff; border-radius: 12px; border: 1px solid #e5e7eb;">
        <div style="text-align: center; margin-bottom: 24px;">
          <h1 style="color: #4f46e5; margin: 0; font-size: 24px; font-weight: 800; letter-spacing: 1.5px;">EQUILIBRIUM</h1>
          <p style="color: #6b7280; margin: 4px 0 0; font-size: 13px;">Autonomous Student Workload Balancer</p>
        </div>
        
        <p style="color: #1f2937; font-size: 16px; margin: 0 0 16px;">${greeting}</p>
        <p style="color: #374151; font-size: 15px; line-height: 1.5; margin: 0 0 24px;">
          Please use the verification code below to confirm your email and complete your account registration:
        </p>

        <div style="background-color: #f3f4f6; border-radius: 8px; padding: 20px; text-align: center; margin-bottom: 24px; border: 1px dashed #cbd5e1;">
          <span style="font-family: 'Courier New', monospace; font-size: 36px; font-weight: 700; letter-spacing: 8px; color: #1e1b4b; display: inline-block;">
            ${otp}
          </span>
        </div>

        <p style="color: #6b7280; font-size: 13px; line-height: 1.5; margin: 0 0 8px;">
          ⏱ <strong>This code expires in 10 minutes.</strong> Never share this code with anyone.
        </p>
        <p style="color: #9ca3af; font-size: 12px; line-height: 1.4; margin: 24px 0 0; border-top: 1px solid #f3f4f6; padding-top: 16px;">
          If you did not request this verification code, you can safely ignore this email. Someone may have entered your email by mistake.
        </p>
      </div>
    `;

    // In test environment, record email and return success
    if (process.env.NODE_ENV === 'test') {
      this.testMailbox.push({
        to: email,
        from: sender,
        subject,
        otp,
        html,
        sentAt: new Date()
      });
      return { success: true };
    }

    // In production/staging, require real Resend configuration
    if (!this.isConfigured()) {
      return {
        success: false,
        error: 'Email delivery is not configured. RESEND_API_KEY environment variable is missing or placeholder.'
      };
    }

    try {
      if (!this.resendClient) {
        this.resendClient = new Resend(config.resendApiKey.trim());
      }

      await this.resendClient.emails.send({
        from: sender,
        to: email,
        subject,
        html
      });

      return { success: true };
    } catch (err: any) {
      // Never log the full error or API key
      const safeMessage = err instanceof Error ? err.message : 'Unknown email transport failure';
      console.error(`[EmailService] Failed to send registration OTP: ${safeMessage}`);
      return { success: false, error: safeMessage };
    }
  }

  /**
   * Send notification if an already registered email attempts registration
   */
  async sendExistingAccountNotice(email: string): Promise<{ success: boolean; error?: string }> {
    const fromAddress = config.emailFrom.includes('@')
      ? config.emailFrom
      : 'onboarding@resend.dev';
    const sender = `Equilibrium <${fromAddress}>`;
    const subject = 'Equilibrium Account Notification';

    const html = `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 560px; margin: 0 auto; padding: 32px 24px; background-color: #ffffff; border-radius: 12px; border: 1px solid #e5e7eb;">
        <h2 style="color: #4f46e5; margin: 0 0 16px;">Equilibrium Account Notification</h2>
        <p style="color: #374151; font-size: 15px; line-height: 1.5; margin: 0 0 16px;">
          Someone recently attempted to create a new Equilibrium account using this email address. However, an account already exists for this email.
        </p>
        <p style="color: #374151; font-size: 15px; line-height: 1.5; margin: 0 0 16px;">
          If this was you, you can open the app and log in with your existing password, or use the "Forgot Password" option to reset your password.
        </p>
        <p style="color: #9ca3af; font-size: 12px; margin-top: 24px; border-top: 1px solid #f3f4f6; padding-top: 16px;">
          If you did not attempt this, you can safely ignore this email. Your account remains secure.
        </p>
      </div>
    `;

    if (process.env.NODE_ENV === 'test') {
      this.testMailbox.push({
        to: email,
        from: sender,
        subject,
        html,
        sentAt: new Date()
      });
      return { success: true };
    }

    if (!this.isConfigured()) return { success: false, error: 'Email service not configured' };

    try {
      if (!this.resendClient) this.resendClient = new Resend(config.resendApiKey.trim());
      await this.resendClient.emails.send({ from: sender, to: email, subject, html });
      return { success: true };
    } catch (err: any) {
      return { success: false, error: err instanceof Error ? err.message : 'Unknown error' };
    }
  }

  /**
   * Send password reset email
   */
  async sendPasswordReset(email: string, resetLink: string): Promise<{ success: boolean; error?: string }> {
    const fromAddress = config.emailFrom.includes('@')
      ? config.emailFrom
      : 'onboarding@resend.dev';
    const sender = `Equilibrium <${fromAddress}>`;
    const subject = 'Equilibrium Password Reset';

    const html = `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 560px; margin: 0 auto; padding: 32px 24px; background-color: #ffffff; border-radius: 12px; border: 1px solid #e5e7eb;">
        <h2 style="color: #4f46e5; margin: 0 0 16px;">Reset your Equilibrium Password</h2>
        <p style="color: #374151; font-size: 15px; line-height: 1.5; margin: 0 0 16px;">
          We received a request to reset the password for your Equilibrium account.
        </p>
        <p style="color: #374151; font-size: 15px; line-height: 1.5; margin: 0 0 24px;">
          Click the button below to choose a new password. This link will expire in 15 minutes.
        </p>
        <div style="text-align: center; margin: 24px 0;">
          <a href="${resetLink}" style="display: inline-block; padding: 12px 28px; background-color: #4f46e5; color: white; text-decoration: none; border-radius: 6px; font-weight: 600; font-size: 15px;">
            Reset Password
          </a>
        </div>
        <p style="color: #9ca3af; font-size: 12px; margin-top: 24px; border-top: 1px solid #f3f4f6; padding-top: 16px;">
          If you did not request this reset, you can safely ignore this email.
        </p>
      </div>
    `;

    if (process.env.NODE_ENV === 'test') {
      this.testMailbox.push({ to: email, from: sender, subject, html, sentAt: new Date() });
      return { success: true };
    }

    if (!this.isConfigured()) return { success: false, error: 'Email service not configured' };

    try {
      if (!this.resendClient) this.resendClient = new Resend(config.resendApiKey.trim());
      await this.resendClient.emails.send({ from: sender, to: email, subject, html });
      return { success: true };
    } catch (err: any) {
      return { success: false, error: err instanceof Error ? err.message : 'Unknown error' };
    }
  }
}

export const emailService = new EmailService();
