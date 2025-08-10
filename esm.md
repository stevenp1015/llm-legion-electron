Directory Structure:

└── ./
    └── @modelcontextprotocol
        └── sdk
            └── dist
                └── esm
                    └── client
                        ├── auth.js
                        ├── index.js
                        ├── sse.js
                        ├── stdio.js
                        ├── streamableHttp.js
                        └── websocket.js



---
File: /@modelcontextprotocol/sdk/dist/esm/client/auth.js
---

import pkceChallenge from "pkce-challenge";
import { LATEST_PROTOCOL_VERSION } from "../types.js";
import { OAuthErrorResponseSchema, OpenIdProviderDiscoveryMetadataSchema } from "../shared/auth.js";
import { OAuthClientInformationFullSchema, OAuthMetadataSchema, OAuthProtectedResourceMetadataSchema, OAuthTokensSchema } from "../shared/auth.js";
import { checkResourceAllowed, resourceUrlFromServerUrl } from "../shared/auth-utils.js";
import { InvalidClientError, InvalidGrantError, OAUTH_ERRORS, OAuthError, ServerError, UnauthorizedClientError } from "../server/auth/errors.js";
export class UnauthorizedError extends Error {
    constructor(message) {
        super(message !== null && message !== void 0 ? message : "Unauthorized");
    }
}
/**
 * Determines the best client authentication method to use based on server support and client configuration.
 *
 * Priority order (highest to lowest):
 * 1. client_secret_basic (if client secret is available)
 * 2. client_secret_post (if client secret is available)
 * 3. none (for public clients)
 *
 * @param clientInformation - OAuth client information containing credentials
 * @param supportedMethods - Authentication methods supported by the authorization server
 * @returns The selected authentication method
 */
function selectClientAuthMethod(clientInformation, supportedMethods) {
    const hasClientSecret = clientInformation.client_secret !== undefined;
    // If server doesn't specify supported methods, use RFC 6749 defaults
    if (supportedMethods.length === 0) {
        return hasClientSecret ? "client_secret_post" : "none";
    }
    // Try methods in priority order (most secure first)
    if (hasClientSecret && supportedMethods.includes("client_secret_basic")) {
        return "client_secret_basic";
    }
    if (hasClientSecret && supportedMethods.includes("client_secret_post")) {
        return "client_secret_post";
    }
    if (supportedMethods.includes("none")) {
        return "none";
    }
    // Fallback: use what we have
    return hasClientSecret ? "client_secret_post" : "none";
}
/**
 * Applies client authentication to the request based on the specified method.
 *
 * Implements OAuth 2.1 client authentication methods:
 * - client_secret_basic: HTTP Basic authentication (RFC 6749 Section 2.3.1)
 * - client_secret_post: Credentials in request body (RFC 6749 Section 2.3.1)
 * - none: Public client authentication (RFC 6749 Section 2.1)
 *
 * @param method - The authentication method to use
 * @param clientInformation - OAuth client information containing credentials
 * @param headers - HTTP headers object to modify
 * @param params - URL search parameters to modify
 * @throws {Error} When required credentials are missing
 */
function applyClientAuthentication(method, clientInformation, headers, params) {
    const { client_id, client_secret } = clientInformation;
    switch (method) {
        case "client_secret_basic":
            applyBasicAuth(client_id, client_secret, headers);
            return;
        case "client_secret_post":
            applyPostAuth(client_id, client_secret, params);
            return;
        case "none":
            applyPublicAuth(client_id, params);
            return;
        default:
            throw new Error(`Unsupported client authentication method: ${method}`);
    }
}
/**
 * Applies HTTP Basic authentication (RFC 6749 Section 2.3.1)
 */
function applyBasicAuth(clientId, clientSecret, headers) {
    if (!clientSecret) {
        throw new Error("client_secret_basic authentication requires a client_secret");
    }
    const credentials = btoa(`${clientId}:${clientSecret}`);
    headers.set("Authorization", `Basic ${credentials}`);
}
/**
 * Applies POST body authentication (RFC 6749 Section 2.3.1)
 */
function applyPostAuth(clientId, clientSecret, params) {
    params.set("client_id", clientId);
    if (clientSecret) {
        params.set("client_secret", clientSecret);
    }
}
/**
 * Applies public client authentication (RFC 6749 Section 2.1)
 */
function applyPublicAuth(clientId, params) {
    params.set("client_id", clientId);
}
/**
 * Parses an OAuth error response from a string or Response object.
 *
 * If the input is a standard OAuth2.0 error response, it will be parsed according to the spec
 * and an instance of the appropriate OAuthError subclass will be returned.
 * If parsing fails, it falls back to a generic ServerError that includes
 * the response status (if available) and original content.
 *
 * @param input - A Response object or string containing the error response
 * @returns A Promise that resolves to an OAuthError instance
 */
export async function parseErrorResponse(input) {
    const statusCode = input instanceof Response ? input.status : undefined;
    const body = input instanceof Response ? await input.text() : input;
    try {
        const result = OAuthErrorResponseSchema.parse(JSON.parse(body));
        const { error, error_description, error_uri } = result;
        const errorClass = OAUTH_ERRORS[error] || ServerError;
        return new errorClass(error_description || '', error_uri);
    }
    catch (error) {
        // Not a valid OAuth error response, but try to inform the user of the raw data anyway
        const errorMessage = `${statusCode ? `HTTP ${statusCode}: ` : ''}Invalid OAuth error response: ${error}. Raw body: ${body}`;
        return new ServerError(errorMessage);
    }
}
/**
 * Orchestrates the full auth flow with a server.
 *
 * This can be used as a single entry point for all authorization functionality,
 * instead of linking together the other lower-level functions in this module.
 */
export async function auth(provider, options) {
    var _a, _b;
    try {
        return await authInternal(provider, options);
    }
    catch (error) {
        // Handle recoverable error types by invalidating credentials and retrying
        if (error instanceof InvalidClientError || error instanceof UnauthorizedClientError) {
            await ((_a = provider.invalidateCredentials) === null || _a === void 0 ? void 0 : _a.call(provider, 'all'));
            return await authInternal(provider, options);
        }
        else if (error instanceof InvalidGrantError) {
            await ((_b = provider.invalidateCredentials) === null || _b === void 0 ? void 0 : _b.call(provider, 'tokens'));
            return await authInternal(provider, options);
        }
        // Throw otherwise
        throw error;
    }
}
async function authInternal(provider, { serverUrl, authorizationCode, scope, resourceMetadataUrl, fetchFn, }) {
    let resourceMetadata;
    let authorizationServerUrl;
    try {
        resourceMetadata = await discoverOAuthProtectedResourceMetadata(serverUrl, { resourceMetadataUrl }, fetchFn);
        if (resourceMetadata.authorization_servers && resourceMetadata.authorization_servers.length > 0) {
            authorizationServerUrl = resourceMetadata.authorization_servers[0];
        }
    }
    catch (_a) {
        // Ignore errors and fall back to /.well-known/oauth-authorization-server
    }
    /**
     * If we don't get a valid authorization server metadata from protected resource metadata,
     * fallback to the legacy MCP spec's implementation (version 2025-03-26): MCP server acts as the Authorization server.
     */
    if (!authorizationServerUrl) {
        authorizationServerUrl = serverUrl;
    }
    const resource = await selectResourceURL(serverUrl, provider, resourceMetadata);
    const metadata = await discoverAuthorizationServerMetadata(authorizationServerUrl, {
        fetchFn,
    });
    // Handle client registration if needed
    let clientInformation = await Promise.resolve(provider.clientInformation());
    if (!clientInformation) {
        if (authorizationCode !== undefined) {
            throw new Error("Existing OAuth client information is required when exchanging an authorization code");
        }
        if (!provider.saveClientInformation) {
            throw new Error("OAuth client information must be saveable for dynamic registration");
        }
        const fullInformation = await registerClient(authorizationServerUrl, {
            metadata,
            clientMetadata: provider.clientMetadata,
        });
        await provider.saveClientInformation(fullInformation);
        clientInformation = fullInformation;
    }
    // Exchange authorization code for tokens
    if (authorizationCode !== undefined) {
        const codeVerifier = await provider.codeVerifier();
        const tokens = await exchangeAuthorization(authorizationServerUrl, {
            metadata,
            clientInformation,
            authorizationCode,
            codeVerifier,
            redirectUri: provider.redirectUrl,
            resource,
            addClientAuthentication: provider.addClientAuthentication,
            fetchFn: fetchFn,
        });
        await provider.saveTokens(tokens);
        return "AUTHORIZED";
    }
    const tokens = await provider.tokens();
    // Handle token refresh or new authorization
    if (tokens === null || tokens === void 0 ? void 0 : tokens.refresh_token) {
        try {
            // Attempt to refresh the token
            const newTokens = await refreshAuthorization(authorizationServerUrl, {
                metadata,
                clientInformation,
                refreshToken: tokens.refresh_token,
                resource,
                addClientAuthentication: provider.addClientAuthentication,
            });
            await provider.saveTokens(newTokens);
            return "AUTHORIZED";
        }
        catch (error) {
            // If this is a ServerError, or an unknown type, log it out and try to continue. Otherwise, escalate so we can fix things and retry.
            if (!(error instanceof OAuthError) || error instanceof ServerError) {
                // Could not refresh OAuth tokens
            }
            else {
                // Refresh failed for another reason, re-throw
                throw error;
            }
        }
    }
    const state = provider.state ? await provider.state() : undefined;
    // Start new authorization flow
    const { authorizationUrl, codeVerifier } = await startAuthorization(authorizationServerUrl, {
        metadata,
        clientInformation,
        state,
        redirectUrl: provider.redirectUrl,
        scope: scope || provider.clientMetadata.scope,
        resource,
    });
    await provider.saveCodeVerifier(codeVerifier);
    await provider.redirectToAuthorization(authorizationUrl);
    return "REDIRECT";
}
export async function selectResourceURL(serverUrl, provider, resourceMetadata) {
    const defaultResource = resourceUrlFromServerUrl(serverUrl);
    // If provider has custom validation, delegate to it
    if (provider.validateResourceURL) {
        return await provider.validateResourceURL(defaultResource, resourceMetadata === null || resourceMetadata === void 0 ? void 0 : resourceMetadata.resource);
    }
    // Only include resource parameter when Protected Resource Metadata is present
    if (!resourceMetadata) {
        return undefined;
    }
    // Validate that the metadata's resource is compatible with our request
    if (!checkResourceAllowed({ requestedResource: defaultResource, configuredResource: resourceMetadata.resource })) {
        throw new Error(`Protected resource ${resourceMetadata.resource} does not match expected ${defaultResource} (or origin)`);
    }
    // Prefer the resource from metadata since it's what the server is telling us to request
    return new URL(resourceMetadata.resource);
}
/**
 * Extract resource_metadata from response header.
 */
export function extractResourceMetadataUrl(res) {
    const authenticateHeader = res.headers.get("WWW-Authenticate");
    if (!authenticateHeader) {
        return undefined;
    }
    const [type, scheme] = authenticateHeader.split(' ');
    if (type.toLowerCase() !== 'bearer' || !scheme) {
        return undefined;
    }
    const regex = /resource_metadata="([^"]*)"/;
    const match = regex.exec(authenticateHeader);
    if (!match) {
        return undefined;
    }
    try {
        return new URL(match[1]);
    }
    catch (_a) {
        return undefined;
    }
}
/**
 * Looks up RFC 9728 OAuth 2.0 Protected Resource Metadata.
 *
 * If the server returns a 404 for the well-known endpoint, this function will
 * return `undefined`. Any other errors will be thrown as exceptions.
 */
export async function discoverOAuthProtectedResourceMetadata(serverUrl, opts, fetchFn = fetch) {
    const response = await discoverMetadataWithFallback(serverUrl, 'oauth-protected-resource', fetchFn, {
        protocolVersion: opts === null || opts === void 0 ? void 0 : opts.protocolVersion,
        metadataUrl: opts === null || opts === void 0 ? void 0 : opts.resourceMetadataUrl,
    });
    if (!response || response.status === 404) {
        throw new Error(`Resource server does not implement OAuth 2.0 Protected Resource Metadata.`);
    }
    if (!response.ok) {
        throw new Error(`HTTP ${response.status} trying to load well-known OAuth protected resource metadata.`);
    }
    return OAuthProtectedResourceMetadataSchema.parse(await response.json());
}
/**
 * Helper function to handle fetch with CORS retry logic
 */
async function fetchWithCorsRetry(url, headers, fetchFn = fetch) {
    try {
        return await fetchFn(url, { headers });
    }
    catch (error) {
        if (error instanceof TypeError) {
            if (headers) {
                // CORS errors come back as TypeError, retry without headers
                return fetchWithCorsRetry(url, undefined, fetchFn);
            }
            else {
                // We're getting CORS errors on retry too, return undefined
                return undefined;
            }
        }
        throw error;
    }
}
/**
 * Constructs the well-known path for auth-related metadata discovery
 */
function buildWellKnownPath(wellKnownPrefix, pathname = '', options = {}) {
    // Strip trailing slash from pathname to avoid double slashes
    if (pathname.endsWith('/')) {
        pathname = pathname.slice(0, -1);
    }
    return options.prependPathname
        ? `${pathname}/.well-known/${wellKnownPrefix}`
        : `/.well-known/${wellKnownPrefix}${pathname}`;
}
/**
 * Tries to discover OAuth metadata at a specific URL
 */
async function tryMetadataDiscovery(url, protocolVersion, fetchFn = fetch) {
    const headers = {
        "MCP-Protocol-Version": protocolVersion
    };
    return await fetchWithCorsRetry(url, headers, fetchFn);
}
/**
 * Determines if fallback to root discovery should be attempted
 */
function shouldAttemptFallback(response, pathname) {
    return !response || response.status === 404 && pathname !== '/';
}
/**
 * Generic function for discovering OAuth metadata with fallback support
 */
async function discoverMetadataWithFallback(serverUrl, wellKnownType, fetchFn, opts) {
    var _a, _b;
    const issuer = new URL(serverUrl);
    const protocolVersion = (_a = opts === null || opts === void 0 ? void 0 : opts.protocolVersion) !== null && _a !== void 0 ? _a : LATEST_PROTOCOL_VERSION;
    let url;
    if (opts === null || opts === void 0 ? void 0 : opts.metadataUrl) {
        url = new URL(opts.metadataUrl);
    }
    else {
        // Try path-aware discovery first
        const wellKnownPath = buildWellKnownPath(wellKnownType, issuer.pathname);
        url = new URL(wellKnownPath, (_b = opts === null || opts === void 0 ? void 0 : opts.metadataServerUrl) !== null && _b !== void 0 ? _b : issuer);
        url.search = issuer.search;
    }
    let response = await tryMetadataDiscovery(url, protocolVersion, fetchFn);
    // If path-aware discovery fails with 404 and we're not already at root, try fallback to root discovery
    if (!(opts === null || opts === void 0 ? void 0 : opts.metadataUrl) && shouldAttemptFallback(response, issuer.pathname)) {
        const rootUrl = new URL(`/.well-known/${wellKnownType}`, issuer);
        response = await tryMetadataDiscovery(rootUrl, protocolVersion, fetchFn);
    }
    return response;
}
/**
 * Looks up RFC 8414 OAuth 2.0 Authorization Server Metadata.
 *
 * If the server returns a 404 for the well-known endpoint, this function will
 * return `undefined`. Any other errors will be thrown as exceptions.
 *
 * @deprecated This function is deprecated in favor of `discoverAuthorizationServerMetadata`.
 */
export async function discoverOAuthMetadata(issuer, { authorizationServerUrl, protocolVersion, } = {}, fetchFn = fetch) {
    if (typeof issuer === 'string') {
        issuer = new URL(issuer);
    }
    if (!authorizationServerUrl) {
        authorizationServerUrl = issuer;
    }
    if (typeof authorizationServerUrl === 'string') {
        authorizationServerUrl = new URL(authorizationServerUrl);
    }
    protocolVersion !== null && protocolVersion !== void 0 ? protocolVersion : (protocolVersion = LATEST_PROTOCOL_VERSION);
    const response = await discoverMetadataWithFallback(authorizationServerUrl, 'oauth-authorization-server', fetchFn, {
        protocolVersion,
        metadataServerUrl: authorizationServerUrl,
    });
    if (!response || response.status === 404) {
        return undefined;
    }
    if (!response.ok) {
        throw new Error(`HTTP ${response.status} trying to load well-known OAuth metadata`);
    }
    return OAuthMetadataSchema.parse(await response.json());
}
/**
 * Builds a list of discovery URLs to try for authorization server metadata.
 * URLs are returned in priority order:
 * 1. OAuth metadata at the given URL
 * 2. OAuth metadata at root (if URL has path)
 * 3. OIDC metadata endpoints
 */
export function buildDiscoveryUrls(authorizationServerUrl) {
    const url = typeof authorizationServerUrl === 'string' ? new URL(authorizationServerUrl) : authorizationServerUrl;
    const hasPath = url.pathname !== '/';
    const urlsToTry = [];
    if (!hasPath) {
        // Root path: https://example.com/.well-known/oauth-authorization-server
        urlsToTry.push({
            url: new URL('/.well-known/oauth-authorization-server', url.origin),
            type: 'oauth'
        });
        // OIDC: https://example.com/.well-known/openid-configuration
        urlsToTry.push({
            url: new URL(`/.well-known/openid-configuration`, url.origin),
            type: 'oidc'
        });
        return urlsToTry;
    }
    // Strip trailing slash from pathname to avoid double slashes
    let pathname = url.pathname;
    if (pathname.endsWith('/')) {
        pathname = pathname.slice(0, -1);
    }
    // 1. OAuth metadata at the given URL
    // Insert well-known before the path: https://example.com/.well-known/oauth-authorization-server/tenant1
    urlsToTry.push({
        url: new URL(`/.well-known/oauth-authorization-server${pathname}`, url.origin),
        type: 'oauth'
    });
    // Root path: https://example.com/.well-known/oauth-authorization-server
    urlsToTry.push({
        url: new URL('/.well-known/oauth-authorization-server', url.origin),
        type: 'oauth'
    });
    // 3. OIDC metadata endpoints
    // RFC 8414 style: Insert /.well-known/openid-configuration before the path
    urlsToTry.push({
        url: new URL(`/.well-known/openid-configuration${pathname}`, url.origin),
        type: 'oidc'
    });
    // OIDC Discovery 1.0 style: Append /.well-known/openid-configuration after the path
    urlsToTry.push({
        url: new URL(`${pathname}/.well-known/openid-configuration`, url.origin),
        type: 'oidc'
    });
    return urlsToTry;
}
/**
 * Discovers authorization server metadata with support for RFC 8414 OAuth 2.0 Authorization Server Metadata
 * and OpenID Connect Discovery 1.0 specifications.
 *
 * This function implements a fallback strategy for authorization server discovery:
 * 1. Attempts RFC 8414 OAuth metadata discovery first
 * 2. If OAuth discovery fails, falls back to OpenID Connect Discovery
 *
 * @param authorizationServerUrl - The authorization server URL obtained from the MCP Server's
 *                                 protected resource metadata, or the MCP server's URL if the
 *                                 metadata was not found.
 * @param options - Configuration options
 * @param options.fetchFn - Optional fetch function for making HTTP requests, defaults to global fetch
 * @param options.protocolVersion - MCP protocol version to use, defaults to LATEST_PROTOCOL_VERSION
 * @returns Promise resolving to authorization server metadata, or undefined if discovery fails
 */
export async function discoverAuthorizationServerMetadata(authorizationServerUrl, { fetchFn = fetch, protocolVersion = LATEST_PROTOCOL_VERSION, } = {}) {
    var _a;
    const headers = { 'MCP-Protocol-Version': protocolVersion };
    // Get the list of URLs to try
    const urlsToTry = buildDiscoveryUrls(authorizationServerUrl);
    // Try each URL in order
    for (const { url: endpointUrl, type } of urlsToTry) {
        const response = await fetchWithCorsRetry(endpointUrl, headers, fetchFn);
        if (!response) {
            throw new Error(`CORS error trying to load ${type === 'oauth' ? 'OAuth' : 'OpenID provider'} metadata from ${endpointUrl}`);
        }
        if (!response.ok) {
            // Continue looking for any 4xx response code.
            if (response.status >= 400 && response.status < 500) {
                continue; // Try next URL
            }
            throw new Error(`HTTP ${response.status} trying to load ${type === 'oauth' ? 'OAuth' : 'OpenID provider'} metadata from ${endpointUrl}`);
        }
        // Parse and validate based on type
        if (type === 'oauth') {
            return OAuthMetadataSchema.parse(await response.json());
        }
        else {
            const metadata = OpenIdProviderDiscoveryMetadataSchema.parse(await response.json());
            // MCP spec requires OIDC providers to support S256 PKCE
            if (!((_a = metadata.code_challenge_methods_supported) === null || _a === void 0 ? void 0 : _a.includes('S256'))) {
                throw new Error(`Incompatible OIDC provider at ${endpointUrl}: does not support S256 code challenge method required by MCP specification`);
            }
            return metadata;
        }
    }
    return undefined;
}
/**
 * Begins the authorization flow with the given server, by generating a PKCE challenge and constructing the authorization URL.
 */
export async function startAuthorization(authorizationServerUrl, { metadata, clientInformation, redirectUrl, scope, state, resource, }) {
    const responseType = "code";
    const codeChallengeMethod = "S256";
    let authorizationUrl;
    if (metadata) {
        authorizationUrl = new URL(metadata.authorization_endpoint);
        if (!metadata.response_types_supported.includes(responseType)) {
            throw new Error(`Incompatible auth server: does not support response type ${responseType}`);
        }
        if (!metadata.code_challenge_methods_supported ||
            !metadata.code_challenge_methods_supported.includes(codeChallengeMethod)) {
            throw new Error(`Incompatible auth server: does not support code challenge method ${codeChallengeMethod}`);
        }
    }
    else {
        authorizationUrl = new URL("/authorize", authorizationServerUrl);
    }
    // Generate PKCE challenge
    const challenge = await pkceChallenge();
    const codeVerifier = challenge.code_verifier;
    const codeChallenge = challenge.code_challenge;
    authorizationUrl.searchParams.set("response_type", responseType);
    authorizationUrl.searchParams.set("client_id", clientInformation.client_id);
    authorizationUrl.searchParams.set("code_challenge", codeChallenge);
    authorizationUrl.searchParams.set("code_challenge_method", codeChallengeMethod);
    authorizationUrl.searchParams.set("redirect_uri", String(redirectUrl));
    if (state) {
        authorizationUrl.searchParams.set("state", state);
    }
    if (scope) {
        authorizationUrl.searchParams.set("scope", scope);
    }
    if (scope === null || scope === void 0 ? void 0 : scope.includes("offline_access")) {
        // if the request includes the OIDC-only "offline_access" scope,
        // we need to set the prompt to "consent" to ensure the user is prompted to grant offline access
        // https://openid.net/specs/openid-connect-core-1_0.html#OfflineAccess
        authorizationUrl.searchParams.append("prompt", "consent");
    }
    if (resource) {
        authorizationUrl.searchParams.set("resource", resource.href);
    }
    return { authorizationUrl, codeVerifier };
}
/**
 * Exchanges an authorization code for an access token with the given server.
 *
 * Supports multiple client authentication methods as specified in OAuth 2.1:
 * - Automatically selects the best authentication method based on server support
 * - Falls back to appropriate defaults when server metadata is unavailable
 *
 * @param authorizationServerUrl - The authorization server's base URL
 * @param options - Configuration object containing client info, auth code, etc.
 * @returns Promise resolving to OAuth tokens
 * @throws {Error} When token exchange fails or authentication is invalid
 */
export async function exchangeAuthorization(authorizationServerUrl, { metadata, clientInformation, authorizationCode, codeVerifier, redirectUri, resource, addClientAuthentication, fetchFn, }) {
    var _a;
    const grantType = "authorization_code";
    const tokenUrl = (metadata === null || metadata === void 0 ? void 0 : metadata.token_endpoint)
        ? new URL(metadata.token_endpoint)
        : new URL("/token", authorizationServerUrl);
    if ((metadata === null || metadata === void 0 ? void 0 : metadata.grant_types_supported) &&
        !metadata.grant_types_supported.includes(grantType)) {
        throw new Error(`Incompatible auth server: does not support grant type ${grantType}`);
    }
    // Exchange code for tokens
    const headers = new Headers({
        "Content-Type": "application/x-www-form-urlencoded",
        "Accept": "application/json",
    });
    const params = new URLSearchParams({
        grant_type: grantType,
        code: authorizationCode,
        code_verifier: codeVerifier,
        redirect_uri: String(redirectUri),
    });
    if (addClientAuthentication) {
        addClientAuthentication(headers, params, authorizationServerUrl, metadata);
    }
    else {
        // Determine and apply client authentication method
        const supportedMethods = (_a = metadata === null || metadata === void 0 ? void 0 : metadata.token_endpoint_auth_methods_supported) !== null && _a !== void 0 ? _a : [];
        const authMethod = selectClientAuthMethod(clientInformation, supportedMethods);
        applyClientAuthentication(authMethod, clientInformation, headers, params);
    }
    if (resource) {
        params.set("resource", resource.href);
    }
    const response = await (fetchFn !== null && fetchFn !== void 0 ? fetchFn : fetch)(tokenUrl, {
        method: "POST",
        headers,
        body: params,
    });
    if (!response.ok) {
        throw await parseErrorResponse(response);
    }
    return OAuthTokensSchema.parse(await response.json());
}
/**
 * Exchange a refresh token for an updated access token.
 *
 * Supports multiple client authentication methods as specified in OAuth 2.1:
 * - Automatically selects the best authentication method based on server support
 * - Preserves the original refresh token if a new one is not returned
 *
 * @param authorizationServerUrl - The authorization server's base URL
 * @param options - Configuration object containing client info, refresh token, etc.
 * @returns Promise resolving to OAuth tokens (preserves original refresh_token if not replaced)
 * @throws {Error} When token refresh fails or authentication is invalid
 */
export async function refreshAuthorization(authorizationServerUrl, { metadata, clientInformation, refreshToken, resource, addClientAuthentication, fetchFn, }) {
    var _a;
    const grantType = "refresh_token";
    let tokenUrl;
    if (metadata) {
        tokenUrl = new URL(metadata.token_endpoint);
        if (metadata.grant_types_supported &&
            !metadata.grant_types_supported.includes(grantType)) {
            throw new Error(`Incompatible auth server: does not support grant type ${grantType}`);
        }
    }
    else {
        tokenUrl = new URL("/token", authorizationServerUrl);
    }
    // Exchange refresh token
    const headers = new Headers({
        "Content-Type": "application/x-www-form-urlencoded",
    });
    const params = new URLSearchParams({
        grant_type: grantType,
        refresh_token: refreshToken,
    });
    if (addClientAuthentication) {
        addClientAuthentication(headers, params, authorizationServerUrl, metadata);
    }
    else {
        // Determine and apply client authentication method
        const supportedMethods = (_a = metadata === null || metadata === void 0 ? void 0 : metadata.token_endpoint_auth_methods_supported) !== null && _a !== void 0 ? _a : [];
        const authMethod = selectClientAuthMethod(clientInformation, supportedMethods);
        applyClientAuthentication(authMethod, clientInformation, headers, params);
    }
    if (resource) {
        params.set("resource", resource.href);
    }
    const response = await (fetchFn !== null && fetchFn !== void 0 ? fetchFn : fetch)(tokenUrl, {
        method: "POST",
        headers,
        body: params,
    });
    if (!response.ok) {
        throw await parseErrorResponse(response);
    }
    return OAuthTokensSchema.parse({ refresh_token: refreshToken, ...(await response.json()) });
}
/**
 * Performs OAuth 2.0 Dynamic Client Registration according to RFC 7591.
 */
export async function registerClient(authorizationServerUrl, { metadata, clientMetadata, fetchFn, }) {
    let registrationUrl;
    if (metadata) {
        if (!metadata.registration_endpoint) {
            throw new Error("Incompatible auth server: does not support dynamic client registration");
        }
        registrationUrl = new URL(metadata.registration_endpoint);
    }
    else {
        registrationUrl = new URL("/register", authorizationServerUrl);
    }
    const response = await (fetchFn !== null && fetchFn !== void 0 ? fetchFn : fetch)(registrationUrl, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
        },
        body: JSON.stringify(clientMetadata),
    });
    if (!response.ok) {
        throw await parseErrorResponse(response);
    }
    return OAuthClientInformationFullSchema.parse(await response.json());
}
//# sourceMappingURL=auth.js.map


---
File: /@modelcontextprotocol/sdk/dist/esm/client/index.js
---

import { mergeCapabilities, Protocol, } from "../shared/protocol.js";
import { CallToolResultSchema, CompleteResultSchema, EmptyResultSchema, GetPromptResultSchema, InitializeResultSchema, LATEST_PROTOCOL_VERSION, ListPromptsResultSchema, ListResourcesResultSchema, ListResourceTemplatesResultSchema, ListToolsResultSchema, ReadResourceResultSchema, SUPPORTED_PROTOCOL_VERSIONS, ErrorCode, McpError, } from "../types.js";
import Ajv from "ajv";
/**
 * An MCP client on top of a pluggable transport.
 *
 * The client will automatically begin the initialization flow with the server when connect() is called.
 *
 * To use with custom types, extend the base Request/Notification/Result types and pass them as type parameters:
 *
 * ```typescript
 * // Custom schemas
 * const CustomRequestSchema = RequestSchema.extend({...})
 * const CustomNotificationSchema = NotificationSchema.extend({...})
 * const CustomResultSchema = ResultSchema.extend({...})
 *
 * // Type aliases
 * type CustomRequest = z.infer<typeof CustomRequestSchema>
 * type CustomNotification = z.infer<typeof CustomNotificationSchema>
 * type CustomResult = z.infer<typeof CustomResultSchema>
 *
 * // Create typed client
 * const client = new Client<CustomRequest, CustomNotification, CustomResult>({
 *   name: "CustomClient",
 *   version: "1.0.0"
 * })
 * ```
 */
export class Client extends Protocol {
    /**
     * Initializes this client with the given name and version information.
     */
    constructor(_clientInfo, options) {
        var _a;
        super(options);
        this._clientInfo = _clientInfo;
        this._cachedToolOutputValidators = new Map();
        this._capabilities = (_a = options === null || options === void 0 ? void 0 : options.capabilities) !== null && _a !== void 0 ? _a : {};
        this._ajv = new Ajv();
    }
    /**
     * Registers new capabilities. This can only be called before connecting to a transport.
     *
     * The new capabilities will be merged with any existing capabilities previously given (e.g., at initialization).
     */
    registerCapabilities(capabilities) {
        if (this.transport) {
            throw new Error("Cannot register capabilities after connecting to transport");
        }
        this._capabilities = mergeCapabilities(this._capabilities, capabilities);
    }
    assertCapability(capability, method) {
        var _a;
        if (!((_a = this._serverCapabilities) === null || _a === void 0 ? void 0 : _a[capability])) {
            throw new Error(`Server does not support ${capability} (required for ${method})`);
        }
    }
    async connect(transport, options) {
        await super.connect(transport);
        // When transport sessionId is already set this means we are trying to reconnect.
        // In this case we don't need to initialize again.
        if (transport.sessionId !== undefined) {
            return;
        }
        try {
            const result = await this.request({
                method: "initialize",
                params: {
                    protocolVersion: LATEST_PROTOCOL_VERSION,
                    capabilities: this._capabilities,
                    clientInfo: this._clientInfo,
                },
            }, InitializeResultSchema, options);
            if (result === undefined) {
                throw new Error(`Server sent invalid initialize result: ${result}`);
            }
            if (!SUPPORTED_PROTOCOL_VERSIONS.includes(result.protocolVersion)) {
                throw new Error(`Server's protocol version is not supported: ${result.protocolVersion}`);
            }
            this._serverCapabilities = result.capabilities;
            this._serverVersion = result.serverInfo;
            // HTTP transports must set the protocol version in each header after initialization.
            if (transport.setProtocolVersion) {
                transport.setProtocolVersion(result.protocolVersion);
            }
            this._instructions = result.instructions;
            await this.notification({
                method: "notifications/initialized",
            });
        }
        catch (error) {
            // Disconnect if initialization fails.
            void this.close();
            throw error;
        }
    }
    /**
     * After initialization has completed, this will be populated with the server's reported capabilities.
     */
    getServerCapabilities() {
        return this._serverCapabilities;
    }
    /**
     * After initialization has completed, this will be populated with information about the server's name and version.
     */
    getServerVersion() {
        return this._serverVersion;
    }
    /**
     * After initialization has completed, this may be populated with information about the server's instructions.
     */
    getInstructions() {
        return this._instructions;
    }
    assertCapabilityForMethod(method) {
        var _a, _b, _c, _d, _e;
        switch (method) {
            case "logging/setLevel":
                if (!((_a = this._serverCapabilities) === null || _a === void 0 ? void 0 : _a.logging)) {
                    throw new Error(`Server does not support logging (required for ${method})`);
                }
                break;
            case "prompts/get":
            case "prompts/list":
                if (!((_b = this._serverCapabilities) === null || _b === void 0 ? void 0 : _b.prompts)) {
                    throw new Error(`Server does not support prompts (required for ${method})`);
                }
                break;
            case "resources/list":
            case "resources/templates/list":
            case "resources/read":
            case "resources/subscribe":
            case "resources/unsubscribe":
                if (!((_c = this._serverCapabilities) === null || _c === void 0 ? void 0 : _c.resources)) {
                    throw new Error(`Server does not support resources (required for ${method})`);
                }
                if (method === "resources/subscribe" &&
                    !this._serverCapabilities.resources.subscribe) {
                    throw new Error(`Server does not support resource subscriptions (required for ${method})`);
                }
                break;
            case "tools/call":
            case "tools/list":
                if (!((_d = this._serverCapabilities) === null || _d === void 0 ? void 0 : _d.tools)) {
                    throw new Error(`Server does not support tools (required for ${method})`);
                }
                break;
            case "completion/complete":
                if (!((_e = this._serverCapabilities) === null || _e === void 0 ? void 0 : _e.completions)) {
                    throw new Error(`Server does not support completions (required for ${method})`);
                }
                break;
            case "initialize":
                // No specific capability required for initialize
                break;
            case "ping":
                // No specific capability required for ping
                break;
        }
    }
    assertNotificationCapability(method) {
        var _a;
        switch (method) {
            case "notifications/roots/list_changed":
                if (!((_a = this._capabilities.roots) === null || _a === void 0 ? void 0 : _a.listChanged)) {
                    throw new Error(`Client does not support roots list changed notifications (required for ${method})`);
                }
                break;
            case "notifications/initialized":
                // No specific capability required for initialized
                break;
            case "notifications/cancelled":
                // Cancellation notifications are always allowed
                break;
            case "notifications/progress":
                // Progress notifications are always allowed
                break;
        }
    }
    assertRequestHandlerCapability(method) {
        switch (method) {
            case "sampling/createMessage":
                if (!this._capabilities.sampling) {
                    throw new Error(`Client does not support sampling capability (required for ${method})`);
                }
                break;
            case "elicitation/create":
                if (!this._capabilities.elicitation) {
                    throw new Error(`Client does not support elicitation capability (required for ${method})`);
                }
                break;
            case "roots/list":
                if (!this._capabilities.roots) {
                    throw new Error(`Client does not support roots capability (required for ${method})`);
                }
                break;
            case "ping":
                // No specific capability required for ping
                break;
        }
    }
    async ping(options) {
        return this.request({ method: "ping" }, EmptyResultSchema, options);
    }
    async complete(params, options) {
        return this.request({ method: "completion/complete", params }, CompleteResultSchema, options);
    }
    async setLoggingLevel(level, options) {
        return this.request({ method: "logging/setLevel", params: { level } }, EmptyResultSchema, options);
    }
    async getPrompt(params, options) {
        return this.request({ method: "prompts/get", params }, GetPromptResultSchema, options);
    }
    async listPrompts(params, options) {
        return this.request({ method: "prompts/list", params }, ListPromptsResultSchema, options);
    }
    async listResources(params, options) {
        return this.request({ method: "resources/list", params }, ListResourcesResultSchema, options);
    }
    async listResourceTemplates(params, options) {
        return this.request({ method: "resources/templates/list", params }, ListResourceTemplatesResultSchema, options);
    }
    async readResource(params, options) {
        return this.request({ method: "resources/read", params }, ReadResourceResultSchema, options);
    }
    async subscribeResource(params, options) {
        return this.request({ method: "resources/subscribe", params }, EmptyResultSchema, options);
    }
    async unsubscribeResource(params, options) {
        return this.request({ method: "resources/unsubscribe", params }, EmptyResultSchema, options);
    }
    async callTool(params, resultSchema = CallToolResultSchema, options) {
        const result = await this.request({ method: "tools/call", params }, resultSchema, options);
        // Check if the tool has an outputSchema
        const validator = this.getToolOutputValidator(params.name);
        if (validator) {
            // If tool has outputSchema, it MUST return structuredContent (unless it's an error)
            if (!result.structuredContent && !result.isError) {
                throw new McpError(ErrorCode.InvalidRequest, `Tool ${params.name} has an output schema but did not return structured content`);
            }
            // Only validate structured content if present (not when there's an error)
            if (result.structuredContent) {
                try {
                    // Validate the structured content (which is already an object) against the schema
                    const isValid = validator(result.structuredContent);
                    if (!isValid) {
                        throw new McpError(ErrorCode.InvalidParams, `Structured content does not match the tool's output schema: ${this._ajv.errorsText(validator.errors)}`);
                    }
                }
                catch (error) {
                    if (error instanceof McpError) {
                        throw error;
                    }
                    throw new McpError(ErrorCode.InvalidParams, `Failed to validate structured content: ${error instanceof Error ? error.message : String(error)}`);
                }
            }
        }
        return result;
    }
    cacheToolOutputSchemas(tools) {
        this._cachedToolOutputValidators.clear();
        for (const tool of tools) {
            // If the tool has an outputSchema, create and cache the Ajv validator
            if (tool.outputSchema) {
                try {
                    const validator = this._ajv.compile(tool.outputSchema);
                    this._cachedToolOutputValidators.set(tool.name, validator);
                }
                catch (_a) {
                    // Ignore schema compilation errors
                }
            }
        }
    }
    getToolOutputValidator(toolName) {
        return this._cachedToolOutputValidators.get(toolName);
    }
    async listTools(params, options) {
        const result = await this.request({ method: "tools/list", params }, ListToolsResultSchema, options);
        // Cache the tools and their output schemas for future validation
        this.cacheToolOutputSchemas(result.tools);
        return result;
    }
    async sendRootsListChanged() {
        return this.notification({ method: "notifications/roots/list_changed" });
    }
}
//# sourceMappingURL=index.js.map


---
File: /@modelcontextprotocol/sdk/dist/esm/client/sse.js
---

import { EventSource } from "eventsource";
import { JSONRPCMessageSchema } from "../types.js";
import { auth, extractResourceMetadataUrl, UnauthorizedError } from "./auth.js";
export class SseError extends Error {
    constructor(code, message, event) {
        super(`SSE error: ${message}`);
        this.code = code;
        this.event = event;
    }
}
/**
 * Client transport for SSE: this will connect to a server using Server-Sent Events for receiving
 * messages and make separate POST requests for sending messages.
 */
export class SSEClientTransport {
    constructor(url, opts) {
        this._url = url;
        this._resourceMetadataUrl = undefined;
        this._eventSourceInit = opts === null || opts === void 0 ? void 0 : opts.eventSourceInit;
        this._requestInit = opts === null || opts === void 0 ? void 0 : opts.requestInit;
        this._authProvider = opts === null || opts === void 0 ? void 0 : opts.authProvider;
        this._fetch = opts === null || opts === void 0 ? void 0 : opts.fetch;
    }
    async _authThenStart() {
        var _a;
        if (!this._authProvider) {
            throw new UnauthorizedError("No auth provider");
        }
        let result;
        try {
            result = await auth(this._authProvider, { serverUrl: this._url, resourceMetadataUrl: this._resourceMetadataUrl, fetchFn: this._fetch });
        }
        catch (error) {
            (_a = this.onerror) === null || _a === void 0 ? void 0 : _a.call(this, error);
            throw error;
        }
        if (result !== "AUTHORIZED") {
            throw new UnauthorizedError();
        }
        return await this._startOrAuth();
    }
    async _commonHeaders() {
        var _a;
        const headers = {};
        if (this._authProvider) {
            const tokens = await this._authProvider.tokens();
            if (tokens) {
                headers["Authorization"] = `Bearer ${tokens.access_token}`;
            }
        }
        if (this._protocolVersion) {
            headers["mcp-protocol-version"] = this._protocolVersion;
        }
        return new Headers({ ...headers, ...(_a = this._requestInit) === null || _a === void 0 ? void 0 : _a.headers });
    }
    _startOrAuth() {
        var _a, _b, _c;
        const fetchImpl = ((_c = (_b = (_a = this === null || this === void 0 ? void 0 : this._eventSourceInit) === null || _a === void 0 ? void 0 : _a.fetch) !== null && _b !== void 0 ? _b : this._fetch) !== null && _c !== void 0 ? _c : fetch);
        return new Promise((resolve, reject) => {
            this._eventSource = new EventSource(this._url.href, {
                ...this._eventSourceInit,
                fetch: async (url, init) => {
                    const headers = await this._commonHeaders();
                    headers.set("Accept", "text/event-stream");
                    const response = await fetchImpl(url, {
                        ...init,
                        headers,
                    });
                    if (response.status === 401 && response.headers.has('www-authenticate')) {
                        this._resourceMetadataUrl = extractResourceMetadataUrl(response);
                    }
                    return response;
                },
            });
            this._abortController = new AbortController();
            this._eventSource.onerror = (event) => {
                var _a;
                if (event.code === 401 && this._authProvider) {
                    this._authThenStart().then(resolve, reject);
                    return;
                }
                const error = new SseError(event.code, event.message, event);
                reject(error);
                (_a = this.onerror) === null || _a === void 0 ? void 0 : _a.call(this, error);
            };
            this._eventSource.onopen = () => {
                // The connection is open, but we need to wait for the endpoint to be received.
            };
            this._eventSource.addEventListener("endpoint", (event) => {
                var _a;
                const messageEvent = event;
                try {
                    this._endpoint = new URL(messageEvent.data, this._url);
                    if (this._endpoint.origin !== this._url.origin) {
                        throw new Error(`Endpoint origin does not match connection origin: ${this._endpoint.origin}`);
                    }
                }
                catch (error) {
                    reject(error);
                    (_a = this.onerror) === null || _a === void 0 ? void 0 : _a.call(this, error);
                    void this.close();
                    return;
                }
                resolve();
            });
            this._eventSource.onmessage = (event) => {
                var _a, _b;
                const messageEvent = event;
                let message;
                try {
                    message = JSONRPCMessageSchema.parse(JSON.parse(messageEvent.data));
                }
                catch (error) {
                    (_a = this.onerror) === null || _a === void 0 ? void 0 : _a.call(this, error);
                    return;
                }
                (_b = this.onmessage) === null || _b === void 0 ? void 0 : _b.call(this, message);
            };
        });
    }
    async start() {
        if (this._eventSource) {
            throw new Error("SSEClientTransport already started! If using Client class, note that connect() calls start() automatically.");
        }
        return await this._startOrAuth();
    }
    /**
     * Call this method after the user has finished authorizing via their user agent and is redirected back to the MCP client application. This will exchange the authorization code for an access token, enabling the next connection attempt to successfully auth.
     */
    async finishAuth(authorizationCode) {
        if (!this._authProvider) {
            throw new UnauthorizedError("No auth provider");
        }
        const result = await auth(this._authProvider, { serverUrl: this._url, authorizationCode, resourceMetadataUrl: this._resourceMetadataUrl, fetchFn: this._fetch });
        if (result !== "AUTHORIZED") {
            throw new UnauthorizedError("Failed to authorize");
        }
    }
    async close() {
        var _a, _b, _c;
        (_a = this._abortController) === null || _a === void 0 ? void 0 : _a.abort();
        (_b = this._eventSource) === null || _b === void 0 ? void 0 : _b.close();
        (_c = this.onclose) === null || _c === void 0 ? void 0 : _c.call(this);
    }
    async send(message) {
        var _a, _b, _c;
        if (!this._endpoint) {
            throw new Error("Not connected");
        }
        try {
            const headers = await this._commonHeaders();
            headers.set("content-type", "application/json");
            const init = {
                ...this._requestInit,
                method: "POST",
                headers,
                body: JSON.stringify(message),
                signal: (_a = this._abortController) === null || _a === void 0 ? void 0 : _a.signal,
            };
            const response = await ((_b = this._fetch) !== null && _b !== void 0 ? _b : fetch)(this._endpoint, init);
            if (!response.ok) {
                if (response.status === 401 && this._authProvider) {
                    this._resourceMetadataUrl = extractResourceMetadataUrl(response);
                    const result = await auth(this._authProvider, { serverUrl: this._url, resourceMetadataUrl: this._resourceMetadataUrl, fetchFn: this._fetch });
                    if (result !== "AUTHORIZED") {
                        throw new UnauthorizedError();
                    }
                    // Purposely _not_ awaited, so we don't call onerror twice
                    return this.send(message);
                }
                const text = await response.text().catch(() => null);
                throw new Error(`Error POSTing to endpoint (HTTP ${response.status}): ${text}`);
            }
        }
        catch (error) {
            (_c = this.onerror) === null || _c === void 0 ? void 0 : _c.call(this, error);
            throw error;
        }
    }
    setProtocolVersion(version) {
        this._protocolVersion = version;
    }
}
//# sourceMappingURL=sse.js.map


---
File: /@modelcontextprotocol/sdk/dist/esm/client/stdio.js
---

import spawn from "cross-spawn";
import process from "node:process";
import { PassThrough } from "node:stream";
import { ReadBuffer, serializeMessage } from "../shared/stdio.js";
/**
 * Environment variables to inherit by default, if an environment is not explicitly given.
 */
export const DEFAULT_INHERITED_ENV_VARS = process.platform === "win32"
    ? [
        "APPDATA",
        "HOMEDRIVE",
        "HOMEPATH",
        "LOCALAPPDATA",
        "PATH",
        "PROCESSOR_ARCHITECTURE",
        "SYSTEMDRIVE",
        "SYSTEMROOT",
        "TEMP",
        "USERNAME",
        "USERPROFILE",
        "PROGRAMFILES",
    ]
    : /* list inspired by the default env inheritance of sudo */
        ["HOME", "LOGNAME", "PATH", "SHELL", "TERM", "USER"];
/**
 * Returns a default environment object including only environment variables deemed safe to inherit.
 */
export function getDefaultEnvironment() {
    const env = {};
    for (const key of DEFAULT_INHERITED_ENV_VARS) {
        const value = process.env[key];
        if (value === undefined) {
            continue;
        }
        if (value.startsWith("()")) {
            // Skip functions, which are a security risk.
            continue;
        }
        env[key] = value;
    }
    return env;
}
/**
 * Client transport for stdio: this will connect to a server by spawning a process and communicating with it over stdin/stdout.
 *
 * This transport is only available in Node.js environments.
 */
export class StdioClientTransport {
    constructor(server) {
        this._abortController = new AbortController();
        this._readBuffer = new ReadBuffer();
        this._stderrStream = null;
        this._serverParams = server;
        if (server.stderr === "pipe" || server.stderr === "overlapped") {
            this._stderrStream = new PassThrough();
        }
    }
    /**
     * Starts the server process and prepares to communicate with it.
     */
    async start() {
        if (this._process) {
            throw new Error("StdioClientTransport already started! If using Client class, note that connect() calls start() automatically.");
        }
        return new Promise((resolve, reject) => {
            var _a, _b, _c, _d, _e;
            this._process = spawn(this._serverParams.command, (_a = this._serverParams.args) !== null && _a !== void 0 ? _a : [], {
                // merge default env with server env because mcp server needs some env vars
                env: {
                    ...getDefaultEnvironment(),
                    ...this._serverParams.env,
                },
                stdio: ["pipe", "pipe", (_b = this._serverParams.stderr) !== null && _b !== void 0 ? _b : "inherit"],
                shell: false,
                signal: this._abortController.signal,
                windowsHide: process.platform === "win32" && isElectron(),
                cwd: this._serverParams.cwd,
            });
            this._process.on("error", (error) => {
                var _a, _b;
                if (error.name === "AbortError") {
                    // Expected when close() is called.
                    (_a = this.onclose) === null || _a === void 0 ? void 0 : _a.call(this);
                    return;
                }
                reject(error);
                (_b = this.onerror) === null || _b === void 0 ? void 0 : _b.call(this, error);
            });
            this._process.on("spawn", () => {
                resolve();
            });
            this._process.on("close", (_code) => {
                var _a;
                this._process = undefined;
                (_a = this.onclose) === null || _a === void 0 ? void 0 : _a.call(this);
            });
            (_c = this._process.stdin) === null || _c === void 0 ? void 0 : _c.on("error", (error) => {
                var _a;
                (_a = this.onerror) === null || _a === void 0 ? void 0 : _a.call(this, error);
            });
            (_d = this._process.stdout) === null || _d === void 0 ? void 0 : _d.on("data", (chunk) => {
                this._readBuffer.append(chunk);
                this.processReadBuffer();
            });
            (_e = this._process.stdout) === null || _e === void 0 ? void 0 : _e.on("error", (error) => {
                var _a;
                (_a = this.onerror) === null || _a === void 0 ? void 0 : _a.call(this, error);
            });
            if (this._stderrStream && this._process.stderr) {
                this._process.stderr.pipe(this._stderrStream);
            }
        });
    }
    /**
     * The stderr stream of the child process, if `StdioServerParameters.stderr` was set to "pipe" or "overlapped".
     *
     * If stderr piping was requested, a PassThrough stream is returned _immediately_, allowing callers to
     * attach listeners before the start method is invoked. This prevents loss of any early
     * error output emitted by the child process.
     */
    get stderr() {
        var _a, _b;
        if (this._stderrStream) {
            return this._stderrStream;
        }
        return (_b = (_a = this._process) === null || _a === void 0 ? void 0 : _a.stderr) !== null && _b !== void 0 ? _b : null;
    }
    /**
     * The child process pid spawned by this transport.
     *
     * This is only available after the transport has been started.
     */
    get pid() {
        var _a, _b;
        return (_b = (_a = this._process) === null || _a === void 0 ? void 0 : _a.pid) !== null && _b !== void 0 ? _b : null;
    }
    processReadBuffer() {
        var _a, _b;
        while (true) {
            try {
                const message = this._readBuffer.readMessage();
                if (message === null) {
                    break;
                }
                (_a = this.onmessage) === null || _a === void 0 ? void 0 : _a.call(this, message);
            }
            catch (error) {
                (_b = this.onerror) === null || _b === void 0 ? void 0 : _b.call(this, error);
            }
        }
    }
    async close() {
        this._abortController.abort();
        this._process = undefined;
        this._readBuffer.clear();
    }
    send(message) {
        return new Promise((resolve) => {
            var _a;
            if (!((_a = this._process) === null || _a === void 0 ? void 0 : _a.stdin)) {
                throw new Error("Not connected");
            }
            const json = serializeMessage(message);
            if (this._process.stdin.write(json)) {
                resolve();
            }
            else {
                this._process.stdin.once("drain", resolve);
            }
        });
    }
}
function isElectron() {
    return "type" in process;
}
//# sourceMappingURL=stdio.js.map


---
File: /@modelcontextprotocol/sdk/dist/esm/client/streamableHttp.js
---

import { isInitializedNotification, isJSONRPCRequest, isJSONRPCResponse, JSONRPCMessageSchema } from "../types.js";
import { auth, extractResourceMetadataUrl, UnauthorizedError } from "./auth.js";
import { EventSourceParserStream } from "eventsource-parser/stream";
// Default reconnection options for StreamableHTTP connections
const DEFAULT_STREAMABLE_HTTP_RECONNECTION_OPTIONS = {
    initialReconnectionDelay: 1000,
    maxReconnectionDelay: 30000,
    reconnectionDelayGrowFactor: 1.5,
    maxRetries: 2,
};
export class StreamableHTTPError extends Error {
    constructor(code, message) {
        super(`Streamable HTTP error: ${message}`);
        this.code = code;
    }
}
/**
 * Client transport for Streamable HTTP: this implements the MCP Streamable HTTP transport specification.
 * It will connect to a server using HTTP POST for sending messages and HTTP GET with Server-Sent Events
 * for receiving messages.
 */
export class StreamableHTTPClientTransport {
    constructor(url, opts) {
        var _a;
        this._url = url;
        this._resourceMetadataUrl = undefined;
        this._requestInit = opts === null || opts === void 0 ? void 0 : opts.requestInit;
        this._authProvider = opts === null || opts === void 0 ? void 0 : opts.authProvider;
        this._fetch = opts === null || opts === void 0 ? void 0 : opts.fetch;
        this._sessionId = opts === null || opts === void 0 ? void 0 : opts.sessionId;
        this._reconnectionOptions = (_a = opts === null || opts === void 0 ? void 0 : opts.reconnectionOptions) !== null && _a !== void 0 ? _a : DEFAULT_STREAMABLE_HTTP_RECONNECTION_OPTIONS;
    }
    async _authThenStart() {
        var _a;
        if (!this._authProvider) {
            throw new UnauthorizedError("No auth provider");
        }
        let result;
        try {
            result = await auth(this._authProvider, { serverUrl: this._url, resourceMetadataUrl: this._resourceMetadataUrl, fetchFn: this._fetch });
        }
        catch (error) {
            (_a = this.onerror) === null || _a === void 0 ? void 0 : _a.call(this, error);
            throw error;
        }
        if (result !== "AUTHORIZED") {
            throw new UnauthorizedError();
        }
        return await this._startOrAuthSse({ resumptionToken: undefined });
    }
    async _commonHeaders() {
        var _a;
        const headers = {};
        if (this._authProvider) {
            const tokens = await this._authProvider.tokens();
            if (tokens) {
                headers["Authorization"] = `Bearer ${tokens.access_token}`;
            }
        }
        if (this._sessionId) {
            headers["mcp-session-id"] = this._sessionId;
        }
        if (this._protocolVersion) {
            headers["mcp-protocol-version"] = this._protocolVersion;
        }
        const extraHeaders = this._normalizeHeaders((_a = this._requestInit) === null || _a === void 0 ? void 0 : _a.headers);
        return new Headers({
            ...headers,
            ...extraHeaders,
        });
    }
    async _startOrAuthSse(options) {
        var _a, _b, _c;
        const { resumptionToken } = options;
        try {
            // Try to open an initial SSE stream with GET to listen for server messages
            // This is optional according to the spec - server may not support it
            const headers = await this._commonHeaders();
            headers.set("Accept", "text/event-stream");
            // Include Last-Event-ID header for resumable streams if provided
            if (resumptionToken) {
                headers.set("last-event-id", resumptionToken);
            }
            const response = await ((_a = this._fetch) !== null && _a !== void 0 ? _a : fetch)(this._url, {
                method: "GET",
                headers,
                signal: (_b = this._abortController) === null || _b === void 0 ? void 0 : _b.signal,
            });
            if (!response.ok) {
                if (response.status === 401 && this._authProvider) {
                    // Need to authenticate
                    return await this._authThenStart();
                }
                // 405 indicates that the server does not offer an SSE stream at GET endpoint
                // This is an expected case that should not trigger an error
                if (response.status === 405) {
                    return;
                }
                throw new StreamableHTTPError(response.status, `Failed to open SSE stream: ${response.statusText}`);
            }
            this._handleSseStream(response.body, options, true);
        }
        catch (error) {
            (_c = this.onerror) === null || _c === void 0 ? void 0 : _c.call(this, error);
            throw error;
        }
    }
    /**
     * Calculates the next reconnection delay using  backoff algorithm
     *
     * @param attempt Current reconnection attempt count for the specific stream
     * @returns Time to wait in milliseconds before next reconnection attempt
     */
    _getNextReconnectionDelay(attempt) {
        // Access default values directly, ensuring they're never undefined
        const initialDelay = this._reconnectionOptions.initialReconnectionDelay;
        const growFactor = this._reconnectionOptions.reconnectionDelayGrowFactor;
        const maxDelay = this._reconnectionOptions.maxReconnectionDelay;
        // Cap at maximum delay
        return Math.min(initialDelay * Math.pow(growFactor, attempt), maxDelay);
    }
    _normalizeHeaders(headers) {
        if (!headers)
            return {};
        if (headers instanceof Headers) {
            return Object.fromEntries(headers.entries());
        }
        if (Array.isArray(headers)) {
            return Object.fromEntries(headers);
        }
        return { ...headers };
    }
    /**
     * Schedule a reconnection attempt with exponential backoff
     *
     * @param lastEventId The ID of the last received event for resumability
     * @param attemptCount Current reconnection attempt count for this specific stream
     */
    _scheduleReconnection(options, attemptCount = 0) {
        var _a;
        // Use provided options or default options
        const maxRetries = this._reconnectionOptions.maxRetries;
        // Check if we've exceeded maximum retry attempts
        if (maxRetries > 0 && attemptCount >= maxRetries) {
            (_a = this.onerror) === null || _a === void 0 ? void 0 : _a.call(this, new Error(`Maximum reconnection attempts (${maxRetries}) exceeded.`));
            return;
        }
        // Calculate next delay based on current attempt count
        const delay = this._getNextReconnectionDelay(attemptCount);
        // Schedule the reconnection
        setTimeout(() => {
            // Use the last event ID to resume where we left off
            this._startOrAuthSse(options).catch(error => {
                var _a;
                (_a = this.onerror) === null || _a === void 0 ? void 0 : _a.call(this, new Error(`Failed to reconnect SSE stream: ${error instanceof Error ? error.message : String(error)}`));
                // Schedule another attempt if this one failed, incrementing the attempt counter
                this._scheduleReconnection(options, attemptCount + 1);
            });
        }, delay);
    }
    _handleSseStream(stream, options, isReconnectable) {
        if (!stream) {
            return;
        }
        const { onresumptiontoken, replayMessageId } = options;
        let lastEventId;
        const processStream = async () => {
            var _a, _b, _c, _d;
            // this is the closest we can get to trying to catch network errors
            // if something happens reader will throw
            try {
                // Create a pipeline: binary stream -> text decoder -> SSE parser
                const reader = stream
                    .pipeThrough(new TextDecoderStream())
                    .pipeThrough(new EventSourceParserStream())
                    .getReader();
                while (true) {
                    const { value: event, done } = await reader.read();
                    if (done) {
                        break;
                    }
                    // Update last event ID if provided
                    if (event.id) {
                        lastEventId = event.id;
                        onresumptiontoken === null || onresumptiontoken === void 0 ? void 0 : onresumptiontoken(event.id);
                    }
                    if (!event.event || event.event === "message") {
                        try {
                            const message = JSONRPCMessageSchema.parse(JSON.parse(event.data));
                            if (replayMessageId !== undefined && isJSONRPCResponse(message)) {
                                message.id = replayMessageId;
                            }
                            (_a = this.onmessage) === null || _a === void 0 ? void 0 : _a.call(this, message);
                        }
                        catch (error) {
                            (_b = this.onerror) === null || _b === void 0 ? void 0 : _b.call(this, error);
                        }
                    }
                }
            }
            catch (error) {
                // Handle stream errors - likely a network disconnect
                (_c = this.onerror) === null || _c === void 0 ? void 0 : _c.call(this, new Error(`SSE stream disconnected: ${error}`));
                // Attempt to reconnect if the stream disconnects unexpectedly and we aren't closing
                if (isReconnectable &&
                    this._abortController &&
                    !this._abortController.signal.aborted) {
                    // Use the exponential backoff reconnection strategy
                    try {
                        this._scheduleReconnection({
                            resumptionToken: lastEventId,
                            onresumptiontoken,
                            replayMessageId
                        }, 0);
                    }
                    catch (error) {
                        (_d = this.onerror) === null || _d === void 0 ? void 0 : _d.call(this, new Error(`Failed to reconnect: ${error instanceof Error ? error.message : String(error)}`));
                    }
                }
            }
        };
        processStream();
    }
    async start() {
        if (this._abortController) {
            throw new Error("StreamableHTTPClientTransport already started! If using Client class, note that connect() calls start() automatically.");
        }
        this._abortController = new AbortController();
    }
    /**
     * Call this method after the user has finished authorizing via their user agent and is redirected back to the MCP client application. This will exchange the authorization code for an access token, enabling the next connection attempt to successfully auth.
     */
    async finishAuth(authorizationCode) {
        if (!this._authProvider) {
            throw new UnauthorizedError("No auth provider");
        }
        const result = await auth(this._authProvider, { serverUrl: this._url, authorizationCode, resourceMetadataUrl: this._resourceMetadataUrl, fetchFn: this._fetch });
        if (result !== "AUTHORIZED") {
            throw new UnauthorizedError("Failed to authorize");
        }
    }
    async close() {
        var _a, _b;
        // Abort any pending requests
        (_a = this._abortController) === null || _a === void 0 ? void 0 : _a.abort();
        (_b = this.onclose) === null || _b === void 0 ? void 0 : _b.call(this);
    }
    async send(message, options) {
        var _a, _b, _c, _d;
        try {
            const { resumptionToken, onresumptiontoken } = options || {};
            if (resumptionToken) {
                // If we have at last event ID, we need to reconnect the SSE stream
                this._startOrAuthSse({ resumptionToken, replayMessageId: isJSONRPCRequest(message) ? message.id : undefined }).catch(err => { var _a; return (_a = this.onerror) === null || _a === void 0 ? void 0 : _a.call(this, err); });
                return;
            }
            const headers = await this._commonHeaders();
            headers.set("content-type", "application/json");
            headers.set("accept", "application/json, text/event-stream");
            const init = {
                ...this._requestInit,
                method: "POST",
                headers,
                body: JSON.stringify(message),
                signal: (_a = this._abortController) === null || _a === void 0 ? void 0 : _a.signal,
            };
            const response = await ((_b = this._fetch) !== null && _b !== void 0 ? _b : fetch)(this._url, init);
            // Handle session ID received during initialization
            const sessionId = response.headers.get("mcp-session-id");
            if (sessionId) {
                this._sessionId = sessionId;
            }
            if (!response.ok) {
                if (response.status === 401 && this._authProvider) {
                    this._resourceMetadataUrl = extractResourceMetadataUrl(response);
                    const result = await auth(this._authProvider, { serverUrl: this._url, resourceMetadataUrl: this._resourceMetadataUrl, fetchFn: this._fetch });
                    if (result !== "AUTHORIZED") {
                        throw new UnauthorizedError();
                    }
                    // Purposely _not_ awaited, so we don't call onerror twice
                    return this.send(message);
                }
                const text = await response.text().catch(() => null);
                throw new Error(`Error POSTing to endpoint (HTTP ${response.status}): ${text}`);
            }
            // If the response is 202 Accepted, there's no body to process
            if (response.status === 202) {
                // if the accepted notification is initialized, we start the SSE stream
                // if it's supported by the server
                if (isInitializedNotification(message)) {
                    // Start without a lastEventId since this is a fresh connection
                    this._startOrAuthSse({ resumptionToken: undefined }).catch(err => { var _a; return (_a = this.onerror) === null || _a === void 0 ? void 0 : _a.call(this, err); });
                }
                return;
            }
            // Get original message(s) for detecting request IDs
            const messages = Array.isArray(message) ? message : [message];
            const hasRequests = messages.filter(msg => "method" in msg && "id" in msg && msg.id !== undefined).length > 0;
            // Check the response type
            const contentType = response.headers.get("content-type");
            if (hasRequests) {
                if (contentType === null || contentType === void 0 ? void 0 : contentType.includes("text/event-stream")) {
                    // Handle SSE stream responses for requests
                    // We use the same handler as standalone streams, which now supports
                    // reconnection with the last event ID
                    this._handleSseStream(response.body, { onresumptiontoken }, false);
                }
                else if (contentType === null || contentType === void 0 ? void 0 : contentType.includes("application/json")) {
                    // For non-streaming servers, we might get direct JSON responses
                    const data = await response.json();
                    const responseMessages = Array.isArray(data)
                        ? data.map(msg => JSONRPCMessageSchema.parse(msg))
                        : [JSONRPCMessageSchema.parse(data)];
                    for (const msg of responseMessages) {
                        (_c = this.onmessage) === null || _c === void 0 ? void 0 : _c.call(this, msg);
                    }
                }
                else {
                    throw new StreamableHTTPError(-1, `Unexpected content type: ${contentType}`);
                }
            }
        }
        catch (error) {
            (_d = this.onerror) === null || _d === void 0 ? void 0 : _d.call(this, error);
            throw error;
        }
    }
    get sessionId() {
        return this._sessionId;
    }
    /**
     * Terminates the current session by sending a DELETE request to the server.
     *
     * Clients that no longer need a particular session
     * (e.g., because the user is leaving the client application) SHOULD send an
     * HTTP DELETE to the MCP endpoint with the Mcp-Session-Id header to explicitly
     * terminate the session.
     *
     * The server MAY respond with HTTP 405 Method Not Allowed, indicating that
     * the server does not allow clients to terminate sessions.
     */
    async terminateSession() {
        var _a, _b, _c;
        if (!this._sessionId) {
            return; // No session to terminate
        }
        try {
            const headers = await this._commonHeaders();
            const init = {
                ...this._requestInit,
                method: "DELETE",
                headers,
                signal: (_a = this._abortController) === null || _a === void 0 ? void 0 : _a.signal,
            };
            const response = await ((_b = this._fetch) !== null && _b !== void 0 ? _b : fetch)(this._url, init);
            // We specifically handle 405 as a valid response according to the spec,
            // meaning the server does not support explicit session termination
            if (!response.ok && response.status !== 405) {
                throw new StreamableHTTPError(response.status, `Failed to terminate session: ${response.statusText}`);
            }
            this._sessionId = undefined;
        }
        catch (error) {
            (_c = this.onerror) === null || _c === void 0 ? void 0 : _c.call(this, error);
            throw error;
        }
    }
    setProtocolVersion(version) {
        this._protocolVersion = version;
    }
    get protocolVersion() {
        return this._protocolVersion;
    }
}
//# sourceMappingURL=streamableHttp.js.map


---
File: /@modelcontextprotocol/sdk/dist/esm/client/websocket.js
---

import { JSONRPCMessageSchema } from "../types.js";
const SUBPROTOCOL = "mcp";
/**
 * Client transport for WebSocket: this will connect to a server over the WebSocket protocol.
 */
export class WebSocketClientTransport {
    constructor(url) {
        this._url = url;
    }
    start() {
        if (this._socket) {
            throw new Error("WebSocketClientTransport already started! If using Client class, note that connect() calls start() automatically.");
        }
        return new Promise((resolve, reject) => {
            this._socket = new WebSocket(this._url, SUBPROTOCOL);
            this._socket.onerror = (event) => {
                var _a;
                const error = "error" in event
                    ? event.error
                    : new Error(`WebSocket error: ${JSON.stringify(event)}`);
                reject(error);
                (_a = this.onerror) === null || _a === void 0 ? void 0 : _a.call(this, error);
            };
            this._socket.onopen = () => {
                resolve();
            };
            this._socket.onclose = () => {
                var _a;
                (_a = this.onclose) === null || _a === void 0 ? void 0 : _a.call(this);
            };
            this._socket.onmessage = (event) => {
                var _a, _b;
                let message;
                try {
                    message = JSONRPCMessageSchema.parse(JSON.parse(event.data));
                }
                catch (error) {
                    (_a = this.onerror) === null || _a === void 0 ? void 0 : _a.call(this, error);
                    return;
                }
                (_b = this.onmessage) === null || _b === void 0 ? void 0 : _b.call(this, message);
            };
        });
    }
    async close() {
        var _a;
        (_a = this._socket) === null || _a === void 0 ? void 0 : _a.close();
    }
    send(message) {
        return new Promise((resolve, reject) => {
            var _a;
            if (!this._socket) {
                reject(new Error("Not connected"));
                return;
            }
            (_a = this._socket) === null || _a === void 0 ? void 0 : _a.send(JSON.stringify(message));
            resolve();
        });
    }
}
//# sourceMappingURL=websocket.js.map
