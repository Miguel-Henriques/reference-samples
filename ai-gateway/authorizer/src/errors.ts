export class InvalidRequestBodyError extends Error { }

export class AuthorizationDeniedError extends Error { }

export class AuthenticationError extends Error { }

export class GuardrailRejectionError extends Error {
    readonly guardrailName: string;

    constructor(guardrailName: string, reason: string) {
        super(reason);
        this.guardrailName = guardrailName;
    }
}

export class TeamNotProvisionedError extends Error {
    readonly teamId: string;

    constructor(teamId: string) {
        super(
            `Team "${teamId}" is not provisioned. Teams must be created by an ` +
            "administrator before the gateway can issue a team-scoped key.",
        );
        this.teamId = teamId;
    }
}

export class KeyManagementError extends Error {
    readonly operation: string;
    readonly status: number;

    constructor(operation: string, status: number, details: string) {
        super(
            `Key management ${operation} failed with ${status}: ` +
            details.slice(0, 500),
        );
        this.operation = operation;
        this.status = status;
    }
}
