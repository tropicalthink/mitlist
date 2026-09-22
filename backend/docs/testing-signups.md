# Mobile testing signups

The landing page at `/mobile-beta` collects an email, one platform (`android`
or `ios`), and explicit consent to testing emails. `/testing` remains an alias
for older links. A separate optional checkbox records consent to launch updates;
declining it never affects beta access. The form creates no app account.
`POST /api/v1/testing/signups` stores the signup in PostgreSQL; migrations
000064 and 000067 are required. The same email may register once per platform.
The endpoint limits requests per IP, caps input at 4 KB, validates the email
and platform, and, when `TURNSTILE_SECRET_KEY` is set, requires a Cloudflare
Turnstile token in `X-Mitlist-Turnstile` — the same proof web guest creation
uses. The landing site sends one when built with `PUBLIC_TURNSTILE_SITE_KEY`.
It sends no email automatically.

## Staffroom tester list

With `STAFFROOM_INTAKE_URL` (for example
`https://reqtrack.tropicalthink.com/api/v1/intake`) and `STAFFROOM_INTAKE_KEY`
(mitlist's intake app key, the one the feedback site uses) set, every accepted
signup is also posted to Staffroom's `POST /intake/testers`, detached from the
response so the landing page never waits on it. Staffroom shows the list under
Apps → mitlist → Testers, with copy-to-clipboard and an "invited" tick per
person. Postgres stays the record; a failed forward is logged and repaired by

```sh
curl -u "$ADMIN_USER:$ADMIN_PASS" -X POST https://api.mitlist.me/api/v1/testing/signups/sync
```

which re-sends everything stored. The intake is idempotent per email and
platform and never resets an "invited" mark, so running it repeatedly is
safe. Run it once right after setting the two variables to backfill.

## Invite testers

The quick path is Staffroom: filter the tester list to the platform, **Copy
emails**, paste into Play Console or App Store Connect, tick the rows as
invited. The CSV export below still works and needs no Staffroom.

1. Open `https://api.mitlist.me/api/v1/testing/signups/export?platform=android`
   or `?platform=ios` using the existing operator HTTP Basic credentials
   (`ADMIN_USER` / `ADMIN_PASS`). The existing `DEBUG_ALLOWLIST` also applies.
   Omit the platform filter to export both. Anonymous access is denied.
2. The CSV contains email, platform, signup time, testing consent, and the
   separate optional launch-update consent and timestamp. Treat it
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

## Send the invitation email (Android is on Google Play)

Once a platform's app is installable, the API can email every signup for it
a styled invitation with the store link, using the normal mail service (SES
in production). The listing comes from `PLAY_STORE_URL` (defaults to the
Google Play page for `me.mitlist`) and `APP_STORE_URL` (empty until the iOS
app has a public TestFlight or App Store link; the iOS invite refuses to send
without it). Migration 000074 adds `invited_at`, so a person is emailed once
no matter how often the endpoint runs.

1. Look at it first, in a browser, with the operator credentials:
   `https://api.mitlist.me/api/v1/testing/signups/invite/preview?platform=android`
   (`&format=text` shows the plain-text alternative).
2. See who would get it without sending anything:

   ```sh
   curl -u "$ADMIN_USER:$ADMIN_PASS" -H 'Content-Type: application/json' \
     -d '{"dry_run":true}' \
     "https://api.mitlist.me/api/v1/testing/signups/invite?platform=android"
   ```

3. Send. The response lists `sent`, `failed`, and `already_invited`. Anyone
   in `failed` was not marked, so running the same command again reaches
   only them:

   ```sh
   curl -u "$ADMIN_USER:$ADMIN_PASS" -X POST \
     "https://api.mitlist.me/api/v1/testing/signups/invite?platform=android"
   ```

Options in the JSON body: `"emails": [...]` limits the run to those
addresses (send yourself one first), `"resend": true` includes people already
invited (their original `invited_at` is kept). The message goes through the
single-provider path, so a provider timeout never fans out into a duplicate.

Testers signed up before this endpoint existed and were invited by hand
through Play Console are not marked; use `emails` or accept that the first
full run reaches them too.

## Withdrawal and retention

Process withdrawal requests sent to `privacy@mitlist.me`, as listed in `/privacy#testing`.
Delete the matching email from `testing_signups`, remove the row in
Staffroom (the trash icon on the tester list), remove it from any exported
copies and store tester lists, and stop sending testing invitations. Use a
parameterized query (`DELETE FROM testing_signups WHERE email = $1`) with the
normalized email; do not interpolate user input into SQL. Remove remaining
signups and exports when the testing programme ends, as stated in the notice.

## Deployment and local verification

Deploy the backend with migrations 000064, 000067 and 000074 first, then the static landing site.
The feature-board link needs no feedback Worker changes. No new mail credentials
or external storage are required. `TESTING_SIGNUP_ORIGIN` defaults to
`https://mitlist.me`. For local landing development, use the development backend
and set `PUBLIC_MITLIST_API_URL=http://localhost:8000/api/v1` (adjust its port).

Turnstile enforcement reaches signups through the same `TURNSTILE_SECRET_KEY`
as guest creation, so the official service already enforces it. Attestation
fails closed: a landing page built without `PUBLIC_TURNSTILE_SITE_KEY` sends no
token, and an enforcing API rejects every signup. Set the site key in the
landing build (and add the landing hostname to the widget in the Cloudflare
dashboard) **before** deploying an API with enforcement, or the form will
return "couldn't save" for everyone.

The handler unit tests can run without PostgreSQL despite the package's
database-dependent TestMain:

```sh
go test ./internal/api/handlers/testing_signup.go ./internal/api/handlers/testing_invite_email.go ./internal/api/handlers/testing_signup_test.go ./internal/api/handlers/testing_invite_test.go ./internal/api/handlers/admin_guard.go
go test ./internal/services/staffroom
go test ./internal/middleware -run Cors
```

The full handler suite additionally checks deduplication against PostgreSQL.
