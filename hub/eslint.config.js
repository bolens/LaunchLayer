import { defineConfig } from "eslint/config";
import convexPlugin from "@convex-dev/eslint-plugin";
import eslint from "@eslint/js";
import tseslint from "typescript-eslint";

export default defineConfig([
	{
		ignores: ["**/node_modules/**", "convex/_generated/**", "vitest.config.ts"],
	},
	eslint.configs.recommended,
	...tseslint.configs.recommended,
	...convexPlugin.configs.recommended,
	{
		files: ["convex/**/*.ts", "test/**/*.ts"],
		languageOptions: {
			parserOptions: {
				projectService: true,
				tsconfigRootDir: import.meta.dirname,
			},
		},
		rules: {
			"@typescript-eslint/no-floating-promises": "error",
			"@typescript-eslint/no-unused-vars": [
				"error",
				{ argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
			],
		},
	},
	{
		// node:test's describe/it return Promises; the runner owns them.
		files: ["**/*.test.ts"],
		rules: {
			"@typescript-eslint/no-floating-promises": "off",
		},
	},
	{
		files: ["convex/lib/validation.ts"],
		rules: {
			// Intentionally rejects C0 controls in user-facing text.
			"no-control-regex": "off",
		},
	},
]);
