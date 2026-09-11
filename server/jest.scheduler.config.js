module.exports = {
  testEnvironment: 'node',
  testMatch: [
    '<rootDir>/test/scheduler*.test.ts',
    '<rootDir>/test/regression*.test.ts'
  ],
  transform: {
    '^.+\\.tsx?$': 'ts-jest'
  }
};
