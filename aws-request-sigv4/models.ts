/**
 * @public
 */
export type RequestSignatureInput = {
  /**
   * AWS service
   */
  service: 'appsync' | 'execute-api';
  /**
   * AWS region
   */
  region: string;
  /**
   * IAM principal to be the request caller.
   * If undefined, role will be resolved from the default credentials provider chain
   */
  roleArn?: string;
  /**
   * Base URL
   */
  hostname: string;
  /**
   * Resource path
   */
  path?: string;
  /**
   * HTTP method
   */
  method: 'GET' | 'POST' | 'PUT';
  /**
   * Request body
   */
  body?: any;
  /**
   * Query parameters
   */
  query?: { [x: string]: string };
  /**
   * Request headers
   */
  headers?: { [x: string]: string };
};

/**
 * @public
 * Represents a Malformed request (HTTP_400),
 * indicating that the request contains elements
 * that are not valid.
 */
export class BadRequestException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'BadRequestException';
  }
}
