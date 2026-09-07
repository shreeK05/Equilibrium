module.exports = {
  testEnvironment: 'node',
  testMatch: ['<rootDir>/test/scheduler*.test.ts'],
  transform: {
    '^.+\\.tsx?$': 'ts-jest'
  }
};
