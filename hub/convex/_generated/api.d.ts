/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as configs from "../configs.js";
import type * as http from "../http.js";
import type * as lib_auth from "../lib/auth.js";
import type * as lib_fingerprint from "../lib/fingerprint.js";
import type * as lib_fixtures from "../lib/fixtures.js";
import type * as lib_machines from "../lib/machines.js";
import type * as lib_publish from "../lib/publish.js";
import type * as lib_ranking from "../lib/ranking.js";
import type * as lib_similarity from "../lib/similarity.js";
import type * as machines from "../machines.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  configs: typeof configs;
  http: typeof http;
  "lib/auth": typeof lib_auth;
  "lib/fingerprint": typeof lib_fingerprint;
  "lib/fixtures": typeof lib_fixtures;
  "lib/machines": typeof lib_machines;
  "lib/publish": typeof lib_publish;
  "lib/ranking": typeof lib_ranking;
  "lib/similarity": typeof lib_similarity;
  machines: typeof machines;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
