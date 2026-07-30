import { AuthenticationError } from '../errors.js';

export async function discoverJwksUrl(issuerUrl: string): Promise<string> {
    const discoveryUrl = `${issuerUrl}/.well-known/openid-configuration`;
    const response = await fetch(discoveryUrl);
    if (!response.ok) {
        throw new Error(
            `OIDC discovery failed: ${discoveryUrl} returned ${response.status}`,
        );
    }
    const document = (await response.json()) as { jwks_uri?: string };
    if (!document.jwks_uri) {
        throw new Error(
            `OIDC discovery document at ${discoveryUrl} has no jwks_uri`,
        );
    }
    return document.jwks_uri;
}

export function extractBearerToken(
    authorizationHeader: string | undefined,
): string {
    if (!authorizationHeader) {
        throw new AuthenticationError("Missing Authorization header");
    }
    const [scheme, token] = authorizationHeader.split(" ", 2);
    if (scheme?.toLowerCase() !== "bearer" || !token) {
        throw new AuthenticationError(
            "Authorization header is not a Bearer token",
        );
    }
    return token;
}