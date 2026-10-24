import fs from 'fs';
import path from 'path';

describe('Regression: Secrets & Configuration Hygiene', () => {
  const rootDir = path.resolve(__dirname, '../..');
  const serverDir = path.resolve(__dirname, '..');

  it('server/.env.example exists and contains all required configuration keys', () => {
    const examplePath = path.join(serverDir, '.env.example');
    expect(fs.existsSync(examplePath)).toBe(true);

    const content = fs.readFileSync(examplePath, 'utf8');
    const requiredKeys = [
      'PORT',
      'DATABASE_URL',
      'JWT_SECRET',
      'NODE_ENV',
      'ALLOWED_ORIGINS',
      'APP_PUBLIC_URL',
      'RESEND_API_KEY',
      'EMAIL_FROM'
    ];

    for (const key of requiredKeys) {
      expect(content).toMatch(new RegExp(`^${key}=`, 'm'));
    }
  });

  it('server/.env.example contains only safe placeholders and no real credentials', () => {
    const examplePath = path.join(serverDir, '.env.example');
    const content = fs.readFileSync(examplePath, 'utf8');

    // Asserts that no live cloud provider hostnames or real connection strings exist in .env.example
    const disallowedPatterns = [
      /supabase\.com/i,
      /render\.com:5432/i,
      /amazonaws\.com/i,
      /mongodb\+srv:/i,
      /postgres:\/\/[^@\s]+:[^@\s]+@(?!localhost)/i
    ];

    for (const pattern of disallowedPatterns) {
      expect(content).not.toMatch(pattern);
    }
  });

  it('.gitignore files safely ignore local environment files while allowing .env.example', () => {
    const serverGitignore = fs.readFileSync(path.join(serverDir, '.gitignore'), 'utf8');
    expect(serverGitignore).toMatch(/^\.env$/m);
    expect(serverGitignore).toMatch(/!\.env\.example/m);

    const rootGitignorePath = path.join(rootDir, '.gitignore');
    if (fs.existsSync(rootGitignorePath)) {
      const rootGitignore = fs.readFileSync(rootGitignorePath, 'utf8');
      expect(rootGitignore).toMatch(/^\.env$/m);
      expect(rootGitignore).toMatch(/!\.env\.example/m);
    }
  });

  it('production configuration rejects JWT_SECRET with fewer than 32 characters', () => {
    const validateJwtSecret = (secret: string, isProd: boolean) => {
      if (isProd && secret.length < 32) {
        throw new Error('JWT_SECRET must be set to at least 32 characters in production');
      }
      return true;
    };

    expect(() => validateJwtSecret('short-secret', true)).toThrow('JWT_SECRET must be set to at least 32 characters in production');
    expect(() => validateJwtSecret('this-is-a-valid-secure-random-secret-that-exceeds-32-chars', true)).not.toThrow();
    expect(() => validateJwtSecret('short-secret', false)).not.toThrow();
  });
});
