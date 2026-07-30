import { GuardrailRejectionError } from '../errors.js';
import type { Guardrail, GuardrailChain, GuardrailRequest } from "./types.js";

/** Runs guardrails sequentially; the first rejection wins. Empty by default. */
export function createGuardrailChain(guardrails: readonly Guardrail[]): GuardrailChain {
    return {
        async run(request: GuardrailRequest): Promise<void> {
            for (const guardrail of guardrails) {
                const result = await guardrail.check(request);
                if (!result.allowed) {
                    throw new GuardrailRejectionError(guardrail.name, result.reason);
                }
            }
        },
    };
}