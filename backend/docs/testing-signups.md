# Mobile testing signups

The landing page at `/testing` collects an email, one platform (`android` or
`ios`), and explicit consent to testing emails. It creates no app account.
`POST /api/v1/testing/signups` stores the signup in PostgreSQL; migration 000064
is required. The same email may register once per platform. Repeats return
the same 202 response without changing the original signup or consent timestamp.
The endpoint limits requests per IP, caps input at 4 KB, validates the email
and platform, and ignores honeypot submissions. It sends no email automatically.

## Invite testers

1. Open `https://api.mitlist.me/api/v1/testing/signups/export?platform=android`
   or `?platform=ios` using the existing operator HTTP Basic credentials
   (`ADMIN_USER` / `ADMIN_PASS`). The existing `DEBUG_ALLOWLIST` also applies.
   Omit the platform filter to export both. Anonymous access is denied.
2. The CSV contains email, platform, signup time, and consent version. Treat it
   as private personal data, never upload it to the public feature board.
   Formula-leading email addresses are prefixed with an apostrophe for safe
   spreadsheet viewing; remove that prefix if importing the address into a store.
3. Android: add the addresses to the tester list in Play Console, attach that
   list to the appropriate test, and email its opt-in link to those testers.
   Just sharing an internal-test URL does not add someone to the allowed list.
4. iOS: add public volunteers to an **external** TestFlight group and send
   invitations through App Store Connect when the build is ready for testing.
   Apple's internal testing is for App Store Connect users, not public signups.
5. Track invitations in your private working copy of the export. No automatic
   approval, invitation sending, or delivery status is implied by signup.

Google: https://support.google.com/googleplay/android-developer/answer/9845334
Apple: https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/

## Withdrawal and retention

Process withdrawal requests sent to the operator email in `/privacy#testing`.
Delete the matching email from `testing_signups`, remove it from any exported
copies and store tester lists, and stop sending testing invitations. Use a
parameterized query (`DELETE FROM testing_signups WHERE email = $1`) with the
normalized email; do not interpolate user input into SQL. Remove remaining
signups and exports when the testing programme ends, as stated in the notice.

## Deployment and local verification

Deploy the backend with migration 000064 first, then the static landing site.
The feature-board link needs no feedback Worker changes. No new mail credentials
or external storage are required. `TESTING_SIGNUP_ORIGIN` defaults to
`https://mitlist.me`. For local landing development, use the development backend
and set `PUBLIC_MITLIST_API_URL=http://localhost:8000/api/v1` (adjust its port).

The handler unit tests can run without PostgreSQL despite the package's
database-dependent TestMain:

```sh
go test ./internal/api/handlers/testing_signup.go ./internal/api/handlers/testing_signup_test.go ./internal/api/handlers/admin_guard.go
go test ./internal/middleware -run Cors
```

The full handler suite additionally checks deduplication against PostgreSQL.
