# AWS identity leg: Entra ID to IAM Identity Center

The same Entra ID user that signs in to GCP also signs in to AWS, with no AWS password and no access keys. The user
lands in the AWS access portal, picks an account and a permission set, and opens the console with that role.

Names below are examples. Use your own tenant, domain, accounts and user. This leg is optional and manual (no Terraform).

## How it differs from the GCP leg
- GCP access follows membership of an Entra group. In this setup AWS access follows the user's assignment to the
  Entra enterprise app plus an assignment in Identity Center. Removing the user's assignment in Entra ends access.
- Making AWS follow groups needs automatic provisioning (SCIM), which adds setup time and may need a paid Entra
  license. This guide skips it and creates the one test user by hand.
- Group assignment to an Entra app can also need a paid Entra license. Assign the user directly.

## Pieces
- An AWS Organization. An organization instance of IAM Identity Center must be enabled from the management account.
  Enable it once and run no workloads there. Give the test user access to a sandbox member account instead.
- Identity Center: single-region organization instance, external identity provider, one user, one permission set.
- Entra: the gallery app "AWS IAM Identity Center (successor to AWS Single Sign-On)" with SAML single sign-on, and
  the test user assigned to it.

## Steps
1. **Enable Identity Center.** In the management account, open IAM Identity Center in a region you will keep. The
   primary region cannot be changed later. Choose a **single-region** instance: the multi-region default creates a
   customer-managed KMS key and replicates to a second region, which adds cost and cleanup. If Identity Center is
   already enabled (for example by Control Tower), stop and check what exists first.
2. **Switch the identity source.** Settings, Identity source, Actions, Change identity source, External identity
   provider. Leave the page open and download the **service provider metadata** file.
3. **Create the Entra app.** Enterprise applications, New application. Pick **AWS IAM Identity Center (successor
   to AWS Single Sign-On)**. Do not pick "AWS Single-Account Access"; that is the older single-account integration.
4. **Configure SAML.** In the app, Single sign-on, SAML, **Upload metadata file** and choose the AWS file from
   step 2. The identifier and reply URL fill in. Save, and skip the test prompt.
5. **Download Entra's metadata.** In SAML Certificates, download **Federation Metadata XML**.
6. **Finish in AWS.** Upload that XML as the IdP SAML metadata, choose Next, type ACCEPT and confirm.
7. **Create the user.** Identity Center, Users, Add user. The username must match the user's Entra sign-in name
   exactly (the `user@tenant.onmicrosoft.com` form). A mismatch is the most common failure. The email and display name
   can be anything; the display name shows in the access portal.
8. **Create a permission set.** Predefined permission set, **ViewOnlyAccess**.
9. **Assign access.** AWS accounts, pick a sandbox member account, Assign users, choose the user and the permission set.
10. **Assign the user in Entra.** In the enterprise app, Users and groups, Add user/group, pick the test user, Assign.

## Sign-in test
In a browser profile with no other identity signed in, open `https://myapps.microsoft.com` as the test user and
complete MFA if asked. Click the AWS tile. In the access portal expand the account, choose the permission set, then
Management console. The console header shows the role and the Entra user. Reads work. A write, such as creating a
security group, is denied.

## Gotchas we hit
- The Entra assignment in step 10 can show an "Application assignment failed" notification on the first try. Refresh
  the app's Users and groups page; the assignment had actually been saved.
- The AWS access portal lists the account ID and email next to the account name. Hide those columns in the portal's
  table preferences if you are recording or sharing the screen.
- The AWS console header always shows the account ID. Blur it in recordings or avoid showing the console live.
- The default region in the console may not be where your resources are; switch it before looking for them.
- Use a clean browser profile so a signed-in personal account does not take over the test.

## Teardown
Delete the Identity Center configuration (IAM Identity Center, Settings, Management, delete the configuration), which
removes the user, permission set and assignments, then delete the Entra enterprise app and the test user.
