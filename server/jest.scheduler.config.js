module.exports = {
  testEnvironment: 'node',
  testMatch: [
    '<rootDir>/test/scheduler*.test.ts',
    '<rootDir>/test/regression*.test.ts'
  ],
  testTimeout: 30000,
  transform: {
    '^.+\\.tsx?$': 'ts-jest'
  }
};
