const isProduction = process.env.NODE_ENV === 'production';
const jwtSecret = process.env.JWT_SECRET || (isProduction ? '' : 'test-secret');

if (isProduction && jwtSecret.length < 32) {
  throw new Error('JWT_SECRET must be set to at least 32 characters in production');
}

export const config = {
  jwtSecret,
  port: Number(process.env.PORT || 3000)
};
