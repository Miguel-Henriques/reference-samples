import { Sha256 } from '@aws-crypto/sha256-js';
import { HttpRequest } from '@aws-sdk/protocol-http';
import { SignatureV4 } from '@aws-sdk/signature-v4';
import { defaultProvider } from '@aws-sdk/credential-provider-node';
import { fromTemporaryCredentials } from '@aws-sdk/credential-providers';
import { Logger } from '@aws-lambda-powertools/logger';
import { BadRequestException, RequestSignatureInput } from './models';

/**
 * Sign AWS requests with selected IAM principals.
 *
 * ```
 * const signatureInput: RequestSignatureInput = {
 *
 *  // Service Endpoint specification
 *  const service = 'execute-api'
 *  const region = 'eu-west-1'
 *
 *  // Optional. IAM principal that will be identified as the request caller (overrides default credentials provider chain)
 *  const roleArn = 'arn:aws:iam::1111111111:role/example'
 *
 *  // Request info
 *  const hostname = 'example-api.com'
 *  const path = '/users'
 *  const method = 'GET'
 *  const query = {
 *    param1: 'paramValue'
 *  }
 *  const body = {
 *    ...
 *  }
 *
 * }
 *
 * await AWSRequestSignatureV4.sign(signatureInput);
 * ```
 *
 * For more, please refer back to the official docs: https:docs.aws.amazon.com/IAM/latest/UserGuide/signing-elements.html
 *
 */
export class AWSRequestSignatureV4 {
  private constructor() {}

  static async sign(input: RequestSignatureInput, addSignatureTo?: 'headers' | 'query', logger?: Logger) {
    const url = new URL(`https://${input.hostname}${input.path || ''}`);
    const request = new HttpRequest({
      hostname: url.hostname,
      path: url.pathname,
      method: input.method,
      headers: {
        ...input.headers,
        host: url.hostname,
      },
    });
    logger?.debug('AWSRequestSignatureV4 | Pre-signed request', { request });

    if (input.query) {
      request.query = input.query;
    }

    if (input.method !== 'GET') {
      if (!input.body) {
        throw new BadRequestException('Request body is missing');
      }
      request.body = input.body;
    }

    const credentialsToUse = input.roleArn
      ? fromTemporaryCredentials({
          params: {
            RoleArn: input.roleArn,
            DurationSeconds: 3600,
          },
        })
      : defaultProvider();

    const signer = new SignatureV4({ credentials: credentialsToUse, service: input.service, region: input.region, sha256: Sha256 });

    let signedRequest;
    if (addSignatureTo === 'headers') {
      signedRequest = await signer.sign(request);
      delete signedRequest.headers.host;
    } else {
      signedRequest = await signer.presign(request);
    }

    logger?.debug('AWSRequestSignatureV4 | Signed request', { signedRequest });
    return signedRequest;
  }
}
