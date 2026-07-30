import type { Context } from 'hono';
import { Hono } from 'hono';
import { AuthenticationError } from './errors.js';
import type { JwtVerifier } from './authn/types.js';
import { extractBearerToken } from './authn/utils.js';
import { AuthorizationDeniedError } from './errors.js';
import type { Authorizer } from './authz/types.js';
import { mapRequestToAction } from './authz/utils.js';
import { GuardrailRejectionError } from './errors.js';
import type { GuardrailChain } from './guardrails/types.js';
import { KeyManagementError, TeamNotProvisionedError } from './errors.js';
import type { KeyExchanger } from './keys/types.js';
import type { UpstreamProxy } from './litellm/types.js';
import type { Logger } from './logger.js';
import { InvalidRequestBodyError } from './errors.js';
import { parseRequestBodyMiddleware, type RequestBodyVariables } from './validators/request-body/parse-request-body.js';

export type AppDependencies = Readonly<{
  verifier: JwtVerifier;
  authorizer: Authorizer;
  guardrails: GuardrailChain;
  keys: KeyExchanger;
  proxy: UpstreamProxy;
  logger: Logger;
}>;

/** Multipart upload routes are not enabled on the gateway yet. */
const BLOCKED_UPLOAD_ROUTES = [
  '/v1/files',
  '/v1/files/*',
  '/v1/audio/transcriptions',
  '/v1/audio/translations',
  '/v1/images/edits',
  '/v1/images/variations',
] as const;

export function buildApp(deps: AppDependencies): Hono<{ Variables: RequestBodyVariables }> {
  const app = new Hono<{ Variables: RequestBodyVariables }>();

  app.onError((error, c) =>
    handleError(c, deps.logger, error, { method: c.req.method, path: c.req.path }),
  );

  // Health check endpoint.
  app.get('/healthz', (c) => c.json({ status: 'ok' }));

  for (const route of BLOCKED_UPLOAD_ROUTES) {
    app.all(route, (c) => routeNotFound(c));
  }

  // Only the OpenAI-compatible data plane is exposed; management APIs
  // (/key/*, /user/*, /team/*) stay reachable exclusively via the interior
  // ALB with the master key.
  app.all('/v1/*', parseRequestBodyMiddleware, (c) => forwardDataPlaneRequest(c, deps));

  app.notFound((c) => routeNotFound(c));

  return app;
}

async function forwardDataPlaneRequest(c: Context, deps: AppDependencies): Promise<Response> {
  const startedAtMs = Date.now();
  const method = c.req.method;
  const path = c.req.path;

  try {
    // 1. Identify the caller (valid JWT from the configured OIDC issuer).
    const token = extractBearerToken(c.req.header('authorization'));
    const identity = await deps.verifier.verify(token);

    const body = c.get('rawBody');
    const parsedBody = c.get('parsedBody');

    // 2. Authorize against Amazon Verified Permissions.
    const actionMapping = mapRequestToAction(method, path, parsedBody);
    await deps.authorizer.authorize({
      identity,
      ...actionMapping,
      context: { path, method },
    });

    /**
     * @experimental
     * 3. Pre-flight guardrails (no-op unless configured). 
     */
    await deps.guardrails.run({
      identity,
      method,
      path,
      body: parsedBody,
    });

    // 4. Exchange the JWT identity for a LiteLLM virtual key.
    const virtualKey = await deps.keys.getVirtualKey(identity);

    // 5. Forward to LiteLLM and stream the response back.
    const url = new URL(c.req.url);
    const proxyRequest = {
      method,
      pathWithQuery: url.pathname + url.search,
      headers: c.req.raw.headers,
      body,
    };
    let response = await deps.proxy.forward(proxyRequest, virtualKey);

    // A 401 upstream can only mean the virtual key is no longer valid
    // (clients never hold one): revoked by an admin, expired, or deleted
    // by a rotation cleanup on another instance. Mint fresh, retry once.
    if (response.status === 401) {
      await response.body?.cancel();
      deps.logger.warn({ sub: identity.sub }, 'cached virtual key rejected; re-minting');
      const freshKey = await deps.keys.refreshVirtualKey(identity);
      response = await deps.proxy.forward(proxyRequest, freshKey);
    }

    deps.logger.info(
      {
        method,
        path,
        sub: identity.sub,
        role: identity.role,
        teamId: identity.teamId,
        status: response.status,
        authorizerMs: Date.now() - startedAtMs,
      },
      'request forwarded',
    );
    return response;
  } catch (error) {
    return handleError(c, deps.logger, error, { method, path });
  }
}

function routeNotFound(c: Context): Response {
  return errorResponse(c, 404, 'not_found', `No route for ${c.req.path}`);
}

function handleError(c: Context, logger: Logger, error: unknown, requestInfo: { method: string; path: string }): Response {
  if (error instanceof AuthenticationError) {
    return errorResponse(c, 401, 'invalid_token', error.message);
  }
  if (error instanceof AuthorizationDeniedError) {
    return errorResponse(c, 403, 'permission_denied', error.message);
  }
  if (error instanceof TeamNotProvisionedError) {
    return errorResponse(c, 403, 'team_not_provisioned', error.message);
  }
  if (error instanceof InvalidRequestBodyError) {
    return errorResponse(c, 400, 'invalid_request_body', error.message);
  }
  if (error instanceof GuardrailRejectionError) {
    return errorResponse(c, 400, 'guardrail_rejected', `Blocked by guardrail "${error.guardrailName}": ${error.message}`);
  }
  if (error instanceof KeyManagementError) {
    logger.error({ ...requestInfo, err: error }, 'key management call failed');
    return errorResponse(c, 502, 'upstream_error', 'The gateway could not process the request');
  }
  logger.error({ ...requestInfo, err: error }, 'unhandled error');
  return errorResponse(c, 500, 'internal_error', 'Internal error');
}

/** OpenAI-style error envelope so client SDKs surface messages natively. */
function errorResponse(c: Context, status: 400 | 401 | 403 | 404 | 500 | 502, code: string, message: string) {
  return c.json({ error: { message, type: 'gateway_error', code } }, status);
}

export function normalizePath(path: string): string {
  const API_VERSION_PREFIX = /^\/v[^/]+\//
  return path.replace(API_VERSION_PREFIX, '/');
}