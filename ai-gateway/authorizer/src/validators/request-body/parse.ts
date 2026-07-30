import { InvalidRequestBodyError } from '../../errors.js'
import { JsonRequestBodySchema, type JsonRequestBody } from './schemas.js'
import { ZodError } from 'zod'

export function parseBufferedRequestBody(
	body: Uint8Array,
	contentType: string | undefined,
	method: string,
): JsonRequestBody | undefined {
	if (body.byteLength === 0) {
		if (['POST', 'PUT', 'PATCH'].includes(method)) {
			throw new InvalidRequestBodyError('Request body must not be empty')
		}
		return undefined
	}

	if (contentType?.includes('application/json')) {
		return parseJsonRequestBody(body)
	}

	throw new InvalidRequestBodyError('Unsupported content type. Must be one of: application/json')
}

export function parseJsonRequestBody(body: Uint8Array): JsonRequestBody | undefined {
	try {
		const decoded = JSON.parse(new TextDecoder().decode(body));
		return JsonRequestBodySchema.parse(decoded);
	} catch (error) {

		if (error instanceof ZodError) {
			throw new InvalidRequestBodyError(formatZodError(error))
		}

		throw new InvalidRequestBodyError('malformed JSON')
	}
}

function formatZodError(error: ZodError): string {
	return error.issues
		.map((issue) => {
			const path = issue.path.length > 0 ? issue.path.join('.') : 'body'
			return `${path}: ${issue.message}`
		})
		.join('; ')
}
