import type { JWTPayload } from "jose";
import { createRemoteJWKSet, jwtVerify } from "jose";
import type { CallerIdentity, JwtVerifier, JwtVerifierOptions } from "./types.js";
import { AuthenticationError } from '../errors.js';
import { discoverJwksUrl } from "./utils.js";

export async function createJwtVerifier(
  options: JwtVerifierOptions,
): Promise<JwtVerifier> {
  const jwksUrl = options.jwksUrl ?? (await discoverJwksUrl(options.issuerUrl));
  const jwks = createRemoteJWKSet(new URL(jwksUrl));

  return {
    async verify(token: string): Promise<CallerIdentity> {
      let payload: JWTPayload;
      try {
        ({ payload } = await jwtVerify(token, jwks, {
          issuer: options.issuerUrl,
        }));
      } catch (error) {
        throw new AuthenticationError(
          error instanceof Error ? error.message : "JWT verification failed",
        );
      }
      if (!payload.sub) {
        throw new AuthenticationError("JWT has no sub claim");
      }
      const roleValue = payload[options.roleClaim];
      if (typeof roleValue !== "string" || roleValue === "") {
        throw new AuthenticationError(
          `JWT has no valid ${options.roleClaim} claim`,
        );
      }
      const teamValue = payload[options.teamClaim];
      return {
        sub: payload.sub,
        role: roleValue,
        ...(typeof teamValue === "string" && teamValue !== ""
          ? { teamId: teamValue }
          : {}),
        claims: payload,
      };
    },
  };
}
