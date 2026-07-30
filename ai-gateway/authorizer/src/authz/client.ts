import type { EntityItem } from "@aws-sdk/client-verifiedpermissions";
import {
  Decision,
  IsAuthorizedCommand,
  VerifiedPermissionsClient,
} from "@aws-sdk/client-verifiedpermissions";
import { type AuthorizationRequest, type Authorizer } from "./types.js";
import { AuthorizationDeniedError } from '../errors.js'

export function createAvpAuthorizer(options: {
  policyStoreId: string;
  region: string;
  namespace: string;
}): Authorizer {
  const { namespace } = options;
  const client = new VerifiedPermissionsClient({ region: options.region });

  return {
    async authorize(request: AuthorizationRequest): Promise<void> {
      const principal = {
        entityType: `${namespace}::User`,
        entityId: request.identity.sub,
      };
      const entities: EntityItem[] = [
        {
          identifier: principal,
          attributes: {
            role: { string: request.identity.role },
          },
        },
      ];

      const response = await client.send(
        new IsAuthorizedCommand({
          policyStoreId: options.policyStoreId,
          principal,
          action: {
            actionType: `${namespace}::Action`,
            actionId: request.action,
          },
          resource: {
            entityType: `${namespace}::${request.resourceType}`,
            entityId: request.resourceId,
          },
          context: {
            contextMap: {
              path: { string: request.context.path },
              method: { string: request.context.method },
            },
          },
          entities: { entityList: entities },
        }),
      );

      if (response.decision !== Decision.ALLOW) {
        const reasons = (response.determiningPolicies ?? [])
          .map((policy) => policy.policyId)
          .filter((id): id is string => id !== undefined);
        throw new AuthorizationDeniedError(
          reasons.length > 0
            ? `Denied by policies: ${reasons.join(", ")}`
            : "No policy permits this request",
        );
      }
    },
  };
}
