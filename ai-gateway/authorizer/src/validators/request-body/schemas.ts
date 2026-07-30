import { z } from 'zod';

export const JsonRequestBodySchema = z.object({
	model: z.string().min(1),
});

export type JsonRequestBody = z.infer<typeof JsonRequestBodySchema>;

export const MultipartRequestBodySchema = z.object({});

export type MultipartRequestBody = z.infer<typeof MultipartRequestBodySchema>;
