# Central admin authentication

This is the shared oauth2-proxy ForwardAuth service for `*.admin.dege.app`.
The service uses the Keycloak OIDC client `admin-auth` and only permits members
of the `homelab-admins` group.

Before reconciliation:

1. Create the Keycloak client using the settings below.
2. Copy `secret.sops.yaml.example` to `secret.sops.yaml`.
3. Fill in the Keycloak client secret and a generated cookie secret.
4. Encrypt the file with SOPS and add it to this kustomization.

The oauth2-proxy ingress is intentionally hosted at `auth.admin.dege.app`.
Protected applications use the Traefik middleware `admin-auth@kubernetescrd`
through the cross-namespace annotation
`traefik-system-admin-auth@kubernetescrd`.

The root `https://admin.dege.app` host is a small authenticated landing page
linking to the protected admin services.

The Keycloak client should use:

- Client ID: `admin-auth`
- Client authentication: on / confidential client
- Standard authorization code flow: on
- Direct access grants and implicit flow: off
- Valid redirect URI: `https://auth.admin.dege.app/oauth2/callback`
- Web origin: `https://auth.admin.dege.app`
- Client scope: `openid profile email`
- Group claim: `groups`, including the `homelab-admins` group

If the realm does not already emit group membership in the `groups` claim,
add a Keycloak group-membership mapper to this client or its assigned client
scope. The user must be a member of `homelab-admins` to pass the proxy policy.

The client secret goes in `client-secret`. Generate a 32-byte cookie secret
with `openssl rand -base64 32`, put it in `cookie-secret`, and encrypt the
resulting Secret with SOPS before adding it to this kustomization.
