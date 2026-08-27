export const config = {
  jwtSecret: process.env.JWT_SECRET || 'test-secret',
  port: process.env.PORT || 3000
};
