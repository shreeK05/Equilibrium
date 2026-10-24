/**
 * Equilibrium — Staging Target Validator & Secure Requester
 *
 * Implements a strict, fail-closed policy to guarantee that staging smoke
 * tests cannot accidentally target production, unexpected hosts, or be redirected
 * to untrusted origins.
 */

export interface ValidationResult {
  valid: boolean;
  error?: string;
  normalizedUrl?: string;
  approvedOrigin?: string;
  hostname?: string;
}

export const FORBIDDEN_PRODUCTION_HOSTS: readonly string[] = [
  'equilibrium-42g8.onrender.com',
  'equilibrium.app',
  'www.equilibrium.app',
  'api.equilibrium.app',
  'prod.equilibrium.app'
];

export function validateStagingTarget(params: {
  targetUrl?: string;
  allowedHost?: string;
  allowLocalhost?: boolean;
}): ValidationResult {
  const { targetUrl, allowedHost, allowLocalhost } = params;

  if (!targetUrl || targetUrl.trim() === '') {
    return { valid: false, error: 'Target URL is required. Please set STAGING_API_URL.' };
  }

  let parsed: URL;
  try {
    parsed = new URL(targetUrl.trim());
  } catch (err: any) {
    return { valid: false, error: `Malformed target URL: ${err.message}` };
  }

  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    return { valid: false, error: `Unsupported protocol "${parsed.protocol}". Only http: and https: are allowed.` };
  }

  const hostname = parsed.hostname.toLowerCase();
  const host = parsed.host.toLowerCase(); // hostname:port

  // 1. Refuse known production domains under all circumstances
  if (FORBIDDEN_PRODUCTION_HOSTS.includes(hostname)) {
    return {
      valid: false,
      error: `Target host "${hostname}" is a forbidden production host. Staging tests cannot target production.`
    };
  }

  // 2. Refuse spoofed production lookalikes (e.g. equilibrium.app.evil.com)
  if (hostname.includes('equilibrium-42g8.onrender.com.') || hostname.includes('equilibrium.app.')) {
    return {
      valid: false,
      error: `Target host "${hostname}" is a forbidden production lookalike domain.`
    };
  }

  const isLocal = hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '::1' || hostname === '[::1]';

  // 2. Localhost policy
  if (isLocal) {
    if (!allowLocalhost) {
      return {
        valid: false,
        error: `Localhost target "${hostname}" rejected. Localhost access is disallowed unless explicit local-test mode is enabled (ALLOW_LOCALHOST=true).`
      };
    }
    const normalizedUrl = parsed.toString().replace(/\/+$/, '');
    return {
      valid: true,
      normalizedUrl,
      approvedOrigin: parsed.origin,
      hostname: parsed.hostname
    };
  }

  // 3. Hosted targets must use HTTPS
  if (parsed.protocol !== 'https:') {
    return {
      valid: false,
      error: `Hosted staging targets must use HTTPS. Received protocol: "${parsed.protocol}".`
    };
  }

  // 4. Fail-closed: Explicit approved hostname is mandatory
  if (!allowedHost || allowedHost.trim() === '') {
    return {
      valid: false,
      error: 'Missing STAGING_ALLOWED_HOST. Staging target validation is fail-closed and requires an explicit approved hostname.'
    };
  }

  const expected = allowedHost.trim().toLowerCase();
  const targetToMatch = expected.includes(':') ? host : hostname;

  if (targetToMatch !== expected) {
    return {
      valid: false,
      error: `Target host "${targetToMatch}" does not match approved staging host "${expected}". Access rejected.`
    };
  }

  // If expected did not specify a port, reject non-standard ports
  if (!expected.includes(':') && parsed.port !== '' && parsed.port !== '443') {
    return {
      valid: false,
      error: `Target host has unexpected port ":${parsed.port}". Expected standard HTTPS port for "${expected}".`
    };
  }

  const normalizedUrl = parsed.toString().replace(/\/+$/, '');
  return {
    valid: true,
    normalizedUrl,
    approvedOrigin: parsed.origin,
    hostname: parsed.hostname
  };
}

export function createSecureRequester(approvedOrigin: string) {
  return async function secureRequest(
    urlStr: string,
    options: RequestInit = {}
  ): Promise<{ status: number; body: any; headers: Headers }> {
    const targetUrl = new URL(urlStr, approvedOrigin);
    if (targetUrl.origin !== approvedOrigin) {
      throw new Error(`Security Violation: Request target origin "${targetUrl.origin}" does not match approved origin "${approvedOrigin}"`);
    }

    const response = await fetch(targetUrl.toString(), {
      ...options,
      redirect: 'manual',
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
    });

    if ([301, 302, 303, 307, 308].includes(response.status)) {
      const location = response.headers.get('location');
      if (!location) {
        throw new Error(`Redirect HTTP ${response.status} with missing Location header`);
      }
      const redirectUrl = new URL(location, targetUrl);
      if (redirectUrl.origin !== approvedOrigin) {
        throw new Error(`Security Violation: Redirect to unapproved origin rejected ("${redirectUrl.origin}")`);
      }
      const nextMethod = [301, 302, 303].includes(response.status) && options.method !== 'GET' ? 'GET' : (options.method || 'GET');
      const nextOptions: RequestInit = {
        ...options,
        method: nextMethod,
        body: nextMethod === 'GET' ? undefined : options.body
      };
      return secureRequest(redirectUrl.toString(), nextOptions);
    }

    let body: any = null;
    const text = await response.text();
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }

    return { status: response.status, body, headers: response.headers };
  };
}
