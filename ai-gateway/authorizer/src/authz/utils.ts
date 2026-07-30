import { normalizePath } from '../app.js'
import type { JsonRequestBody } from '../validators/request-body/schemas.js'
import type { AuthorizationMapping } from './types.js'

export function mapRequestToAction(
  method: string,
  path: string,
  parsedBody: JsonRequestBody | undefined,
): AuthorizationMapping {

  const _path = normalizePath(path)

  if (method === 'GET' && _path === '/models') {
    return {
      action: 'ListModels',
      resourceType: 'Gateway',
      resourceId: 'gateway',
    }
  }

  //FIXME: general fallback for now
  return {
    action: 'InvokeModel',
    resourceType: 'Model',
    resourceId: parsedBody?.model ?? 'unknown',
  }
}
