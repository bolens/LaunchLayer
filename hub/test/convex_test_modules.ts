/// <reference types="vite/client" />

const tsModules = import.meta.glob("../convex/**/*.ts");
const jsModules = import.meta.glob("../convex/**/*.js");

/** Module map for convex-test (must include `_generated/*.js`). */
export const modules = Object.fromEntries(
  Object.entries({ ...tsModules, ...jsModules }).filter(([path]) => {
    if (path.includes(".test.")) return false;
    if (path.endsWith("test_helpers.ts")) return false;
    if (path.endsWith("convex_test_modules.ts")) return false;
    return true;
  }),
);
