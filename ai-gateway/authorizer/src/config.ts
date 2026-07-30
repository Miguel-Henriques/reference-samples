import { z } from "zod";

const envSchema = z.object({
  PORT: z.coerce.number().int().positive().default(8080),
  LOG_LEVEL: z.enum(["trace", "debug", "info", "warn", "error"]).default("info"),

  // Upstream LiteLLM deployment (the module-managed ALB).
  LITELLM_BASE_URL: z.url(),
  LITELLM_MASTER_KEY: z.string().min(1),

  // External OIDC issuer that signs caller JWTs.
  OIDC_ISSUER_URL: z.url(),
  // Optional override; defaults to the issuer's discovery document jwks_uri.
  OIDC_JWKS_URL: z.url().optional(),
  // Claim that carries the caller's authorization role.
  OIDC_ROLE_CLAIM: z.string().default("role"),
  // Claim that carries the caller's LiteLLM team id, when present.
  OIDC_TEAM_CLAIM: z.string().default("team_id"),

  // Amazon Verified Permissions. Namespace must match the Cedar schema
  // top-level key (Terraform injects it from policies/schema.json).
  AVP_POLICY_STORE_ID: z.string().min(1),
  AVP_NAMESPACE: z.string().min(1),
  AWS_REGION: z.string().min(1),

  // Virtual key exchange. Keys expire server-side after VIRTUAL_KEY_DURATION,
  // so cache entries must live shorter than the key itself.
  VIRTUAL_KEY_DURATION: z
    .string()
    .regex(/^\d+[smhd]$/, "expected a LiteLLM duration such as 30d or 12h")
    .default("30d"),
  // 7 days: rotation (and its cleanup pass) roughly once a week per caller.
  KEY_CACHE_TTL_SECONDS: z.coerce.number().int().positive().default(28_800), // 8 hours
  // After minting, older authorizer-issued keys for the caller are deleted —
  // except ones younger than this, protecting concurrent mints elsewhere.
  KEY_CLEANUP_GRACE_SECONDS: z.coerce.number().int().nonnegative().default(300),
  // Applied to users auto-created on first request. Empty string = no budget.
  DEFAULT_USER_MAX_BUDGET_USD: z.coerce.number().positive().optional(),

  // Optional distributed cache. In-memory only when unset.
  REDIS_URL: z.url().optional(),
});

export type StartupSummary = Readonly<{
  port: number;
  logLevel: Config["logLevel"];
  cache: Readonly<{ mode: "memory" } | { mode: "redis"; host: string; tls: boolean }>;
  litellm: Readonly<{ baseUrl: string; masterKey: "configured" }>;
  oidc: Readonly<{
    issuerUrl: string;
    jwksUrl: string | "discovery";
    roleClaim: string;
    teamClaim: string;
  }>;
  avp: Readonly<{ policyStoreId: string; region: string; namespace: string }>;
  keys: Readonly<{
    virtualKeyDuration: string;
    cacheTtlSeconds: number;
    cleanupGraceSeconds: number;
    defaultUserMaxBudgetUsd: number | "none";
  }>;
  guardrails: Readonly<{ preflightCount: number }>;
}>;

export type Config = Readonly<{
  port: number;
  logLevel: "trace" | "debug" | "info" | "warn" | "error";
  litellm: { baseUrl: string; masterKey: string };
  oidc: {
    issuerUrl: string;
    jwksUrl?: string;
    roleClaim: string;
    teamClaim: string;
  };
  avp: { policyStoreId: string; region: string; namespace: string };
  keys: {
    virtualKeyDuration: string;
    cacheTtlSeconds: number;
    cleanupGraceSeconds: number;
    defaultUserMaxBudgetUsd?: number;
  };
  redisUrl?: string;
}>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const parsed = envSchema.safeParse(env);
  if (!parsed.success) {
    const issues = parsed.error.issues
      .map((issue) => `${issue.path.join(".")}: ${issue.message}`)
      .join("; ");
    throw new Error(`Invalid configuration: ${issues}`);
  }
  const e = parsed.data;

  const durationSeconds = litellmDurationToSeconds(e.VIRTUAL_KEY_DURATION);
  if (e.KEY_CACHE_TTL_SECONDS >= durationSeconds) {
    throw new Error(
      `Invalid configuration: KEY_CACHE_TTL_SECONDS (${e.KEY_CACHE_TTL_SECONDS}) must be ` +
      `shorter than VIRTUAL_KEY_DURATION (${e.VIRTUAL_KEY_DURATION} = ${durationSeconds}s), ` +
      "otherwise cached keys outlive their server-side expiry",
    );
  }

  return {
    port: e.PORT,
    logLevel: e.LOG_LEVEL,
    litellm: { baseUrl: stripTrailingSlash(e.LITELLM_BASE_URL), masterKey: e.LITELLM_MASTER_KEY },
    oidc: {
      issuerUrl: stripTrailingSlash(e.OIDC_ISSUER_URL),
      ...(e.OIDC_JWKS_URL ? { jwksUrl: e.OIDC_JWKS_URL } : {}),
      roleClaim: e.OIDC_ROLE_CLAIM,
      teamClaim: e.OIDC_TEAM_CLAIM,
    },
    avp: {
      policyStoreId: e.AVP_POLICY_STORE_ID,
      region: e.AWS_REGION,
      namespace: e.AVP_NAMESPACE,
    },
    keys: {
      virtualKeyDuration: e.VIRTUAL_KEY_DURATION,
      cacheTtlSeconds: e.KEY_CACHE_TTL_SECONDS,
      cleanupGraceSeconds: e.KEY_CLEANUP_GRACE_SECONDS,
      ...(e.DEFAULT_USER_MAX_BUDGET_USD !== undefined
        ? { defaultUserMaxBudgetUsd: e.DEFAULT_USER_MAX_BUDGET_USD }
        : {}),
    },
    ...(e.REDIS_URL ? { redisUrl: e.REDIS_URL } : {}),
  };
}

export function litellmDurationToSeconds(duration: string): number {
  const match = /^(\d+)([smhd])$/.exec(duration);
  if (!match) throw new Error(`Unparseable duration: ${duration}`);
  const value = Number(match[1]);
  const unit = match[2] as "s" | "m" | "h" | "d";
  const multiplier = { s: 1, m: 60, h: 3_600, d: 86_400 }[unit];
  return value * multiplier;
}

export function buildStartupSummary(
  config: Config,
  options: Readonly<{ preflightGuardrailCount: number }> = {
    preflightGuardrailCount: 0,
  },
): StartupSummary {
  return {
    port: config.port,
    logLevel: config.logLevel,
    cache: config.redisUrl
      ? { mode: "redis", ...describeRedisEndpoint(config.redisUrl) }
      : { mode: "memory" },
    litellm: { baseUrl: config.litellm.baseUrl, masterKey: "configured" },
    oidc: {
      issuerUrl: config.oidc.issuerUrl,
      jwksUrl: config.oidc.jwksUrl ?? "discovery",
      roleClaim: config.oidc.roleClaim,
      teamClaim: config.oidc.teamClaim,
    },
    avp: config.avp,
    keys: {
      virtualKeyDuration: config.keys.virtualKeyDuration,
      cacheTtlSeconds: config.keys.cacheTtlSeconds,
      cleanupGraceSeconds: config.keys.cleanupGraceSeconds,
      defaultUserMaxBudgetUsd:
        config.keys.defaultUserMaxBudgetUsd ?? "none",
    },
    guardrails: { preflightCount: options.preflightGuardrailCount },
  };
}

function describeRedisEndpoint(
  redisUrl: string,
): Readonly<{ host: string; tls: boolean }> {
  const parsed = new URL(redisUrl);
  return { host: parsed.host, tls: parsed.protocol === "rediss:" };
}

function stripTrailingSlash(url: string): string {
  return url.endsWith("/") ? url.slice(0, -1) : url;
}
