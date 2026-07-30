import type { CallerIdentity } from "../authn/types.js";

export type AuthorizationRequest = Readonly<{
  identity: CallerIdentity;
  action: string;
  resourceType: "Model" | "Gateway";
  resourceId: string;
  context: Readonly<{ path: string; method: string }>;
}>;

export type AuthorizationMapping = Pick<
  AuthorizationRequest,
  "action" | "resourceType" | "resourceId"
>;

export type Authorizer = Readonly<{
  authorize(request: AuthorizationRequest): Promise<void>;
}>;