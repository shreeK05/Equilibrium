module.exports = {
  testEnvironment: 'node',
  testMatch: [
    '<rootDir>/test/scheduler*.test.ts',
    '<rootDir>/test/regression*.test.ts'
  ],
  testTimeout: 30000,
  globalSetup: undefined,
  transform: {
    '^.+\\.tsx?$': 'ts-jest'
  }
};
