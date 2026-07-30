import type { JWTPayload } from "jose";

export type CallerIdentity = Readonly<{
  sub: string;
  role: string;
  teamId?: string;
  claims: JWTPayload;
}>;

export type JwtVerifier = Readonly<{
  verify(token: string): Promise<CallerIdentity>;
}>;

export type JwtVerifierOptions = Readonly<{
  issuerUrl: string;
  jwksUrl?: string;
  roleClaim: string;
  teamClaim: string;
}>;
