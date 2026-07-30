import { createMiddleware } from 'hono/factory'
import { parseBufferedRequestBody } from './parse.js'
import type { JsonRequestBody } from './schemas.js'

export type RequestBodyVariables = Readonly<{
	rawBody: Uint8Array | undefined
	parsedBody: JsonRequestBody | undefined
}>

export const parseRequestBodyMiddleware = createMiddleware<{ Variables: RequestBodyVariables }>(
	async (c, next) => {
		const body = new Uint8Array(await c.req.arrayBuffer())

		const parsedBody = parseBufferedRequestBody(
			body,
			c.req.header('content-type'),
			c.req.method,
		)

		if (body.byteLength > 0) {
			c.set('rawBody', body)
		}

		if (parsedBody) {
			c.set('parsedBody', parsedBody)
		}

		await next()
	},
)
