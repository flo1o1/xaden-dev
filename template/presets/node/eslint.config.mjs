// Clean-code preset for JavaScript/TypeScript (xaden project add-preset node).
// Each rule is mapped to the AGENTS.md rule it enforces. Relaxing a rule needs the user's approval
// and a comment with the reason (AGENTS.md §5).
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  { ignores: ["dist/", "build/", "coverage/", "node_modules/"] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    rules: {
      complexity: ["error", 8], // CC-01: functions do one thing
      "max-lines-per-function": ["error", { max: 40, skipBlankLines: true, skipComments: true }], // CC-01
      "max-params": ["error", 4], // CC-01
      "max-depth": ["error", 3], // CC-03: no deep nesting
      "no-else-return": "error", // CC-03: early return
      "no-magic-numbers": ["error", { ignore: [-1, 0, 1, 2], ignoreDefaultValues: true }], // CC-02
      camelcase: "error", // CC-02
      "no-empty": "error", // CC-05: never swallow errors
      "no-eval": "error", // security
      "no-implied-eval": "error", // security
      "no-new-func": "error", // security
      eqeqeq: "error",
      "no-var": "error", // block scope only; var hoisting hides intent (CC-02)
      "prefer-const": "error",
    },
  },
  {
    files: ["**/*.test.*", "**/*.spec.*", "tests/**"],
    rules: { "no-magic-numbers": "off", "max-lines-per-function": "off" }, // test data and describe blocks
  },
);
