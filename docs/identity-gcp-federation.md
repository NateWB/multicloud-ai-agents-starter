# GCP identity leg: Entra ID to Workforce Identity Federation

One identity provider (Entra ID) signs people in to GCP with no Google accounts. Access follows Entra group
membership: remove the user from the group and access ends, with no change in GCP.

Names below are examples. Use your own tenant, domain, project and group.

## Pieces
- GCP organization with Cloud Identity. Your admin needs organization admin and workforce pool admin roles.
- Workforce pool (organization level, location `global`) and an OIDC provider for Entra, implicit flow (ID token),
  vendor type entra-id, attribute mapping: subject = oid, groups = groups, display name = preferred_username.
- IAM: a viewer role on your project for the pool's group principal set (the Entra group object ID).
- Entra: an app registration (single tenant, ID tokens enabled, `groupMembershipClaims` = SecurityGroup, redirect URI
  below), its service principal, a security group, and a native test user in that group.
- Redirect URI: `https://auth.cloud.google/signin-callback/locations/global/workforcePools/<pool>/providers/<provider>`

## Sign-in
`https://auth.cloud.google/signin?continueUrl=https://console.cloud.google/` then enter
`locations/global/workforcePools/<pool>/providers/<provider>` when asked for the provider.

## Gotchas we hit
- `az ad app create` does not create the service principal; run `az ad sp create --id <client id>`.
- Entra security defaults force MFA registration for a new user (once). The first sign-in also shows a consent screen.
- If your domain isn't verified in Entra, use the `<tenant>.onmicrosoft.com` domain for the test user.
- The federated user sees "No organization" in the console. That is normal.
- zsh: comments with apostrophes and multi-line pastes break; run one-line commands.

## Teardown
Delete the provider, then the pool (`gcloud iam workforce-pools providers delete`, `gcloud iam workforce-pools delete`),
the IAM binding, and the Entra app, group and test user. Pools are soft-deleted for 30 days.
