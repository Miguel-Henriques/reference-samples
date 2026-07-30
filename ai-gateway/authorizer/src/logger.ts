import type { Logger, LoggerOptions } from 'pino';
import { pino } from 'pino';

export type { Logger };

const sharedOptions = {
	redact: ['req.headers.authorization'],
} satisfies LoggerOptions;

export function createLogger(level: string): Logger {
	if (process.env.NODE_ENV === 'development') {
		return pino({
			level,
			...sharedOptions,
			transport: {
				target: 'pino-pretty',
				options: {
					colorize: true,
					ignore: 'pid,hostname',
					translateTime: 'SYS:standard',
				},
			},
		});
	}

	return pino({
		level,
		...sharedOptions,
		formatters: {
			level: (label) => ({ level: label }),
		},
	});
}
