import type { CallerIdentity } from "../authn/types.js";

export type GuardrailRequest = Readonly<{
    identity: CallerIdentity;
    method: string;
    path: string;
    /** Parsed JSON body when the request carried one; undefined otherwise. */
    body: unknown;
}>;

export type GuardrailResult =
    | Readonly<{ allowed: true }>
    | Readonly<{ allowed: false; reason: string }>;

/**
 * Pre-flight request guardrail. LiteLLM applies its own (native) guardrails
 * downstream; this hook exists for checks that must run before the request
 * ever reaches the gateway — e.g. tenant-specific input screening.
 */
export type Guardrail = Readonly<{
    name: string;
    check(request: GuardrailRequest): Promise<GuardrailResult>;
}>;

export type GuardrailChain = Readonly<{
    run(request: GuardrailRequest): Promise<void>;
}>;

