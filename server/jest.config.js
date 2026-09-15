const { createDefaultPreset } = require("ts-jest");

const tsJestTransformCfg = createDefaultPreset().transform;

/** @type {import("jest").Config} **/
module.exports = {
  testEnvironment: "node",
  testMatch: ["<rootDir>/test/**/*.test.ts"],
  globalSetup: "<rootDir>/test/global-setup.js",
  testTimeout: 30000,
  transform: {
    ...tsJestTransformCfg,
  },
};