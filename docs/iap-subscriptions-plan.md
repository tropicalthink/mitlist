# In-App Purchase (IAP) subscriptions — execution plan

> **Status (2026-08-12): code implemented and hardened; store setup pending.** The backend
> (verification, notifications, config) and the Flutter paywall branch are done
> and tested/analyzed. The iOS project capability is present and Android's
> billing permission comes from the plugin. What remains is store-console setup,
> release signing/provisioning, and device testing in sandbox — see §9. The
> canonical product ids are listed below and must be created exactly as written.


> Native StoreKit / Google Play Billing as **additional payment providers**
> alongside the existing Polar web checkout. No third-party paywall SDK
> (RevenueCat et al.) — the backend already owns entitlement, and a 1%-of-revenue
> middleman on top of Apple/Google/Polar cuts is not worth it.
>
> Grounded in files read on 2026-08-10. Product IDs and price points below are
> proposals — confirm them in the store consoles before wiring config.

---

## 1. Why this work exists

Apple (App Store Guideline 3.1.1) and Google (Play Payments policy) require that
digital entitlements consumed inside the app be sold through **StoreKit** and
**Google Play Billing**. The current flow — `frontend/lib/sheets/premium_sheet.dart`
opens a Polar hosted-checkout URL via `launchUrl(...externalApplication)` — is a
guaranteed store rejection on iOS/Android. It stays correct for web and self-host.

**The model does not change.** A subscription still covers exactly one "premium
household" (`billing_subscriptions.primary_group_id`), the free limit is still
`FREE_MEMBER_LIMIT` (default 4, `services.DefaultFreeMemberLimit`), and
entitlement is still computed by `BillingService.GetHouseholdEntitlement` /
`EnsureCanAddMember`. Those are provider-agnostic and untouched by this plan.

What is new is **two more values of `billing_subscriptions.provider`**
(`'apple'`, `'google'`) and the code paths that verify a native purchase and
keep its renewal state current.

### What already exists and is reusable

- `billing_subscriptions.provider` — generic column, `'polar'` today. (migration `000037`)
- `UNIQUE (provider, provider_subscription_id)` — natural key already provider-scoped.
- `billing_webhook_events` — idempotency table keyed on delivery id. Reuse for
  Apple `notificationUUID` and Google RTDN message ids.
- `provider_modified_at` — out-of-order delivery guard.
- `BillingService.ApplyWebhookEvent` — the upsert shape both new providers target.
- `resolveUser` / `resolveGroup` — user+group resolution from provider metadata.
- Frontend `HouseholdEntitlement` / `BillingStatus` models — unchanged.

---

## 2. Pricing: annual +€2 on IAP, monthly unchanged

| Plan    | Web (Polar) | IAP (App Store / Play) |
|---------|-------------|------------------------|
| Monthly | €2.00       | **€2.00** (identical — store cut absorbed) |
| Annual  | €18.00      | **€20.00** (+€2 — passes the ~€1.5 store cut, rounded up) |

EU prices confirmed 2026-08-10. Rest-of-world uplift handled later; for now the
stores auto-convert the EUR base, and the +€2 is baked into the EUR annual base.

Rules:
- Set the EUR base price in each store; store systems auto-convert other
  territories. Bake the +€2 into the **EUR annual base** so the uplift converts
  naturally everywhere (don't try to add a flat €2 per territory).
- The app must **display the store's own localized price string** on mobile
  (`ProductDetails.price` from `in_app_purchase`), NOT the backend Polar plan
  price. Otherwise a mobile user sees the web number, which is wrong by €2.
- `GET /billing/status` `plans[]` (from `BillingService.GetPlans`, read from
  Polar) remains the **web** price source only.

---

## 3. Store console setup (manual — do first, code depends on the IDs)

### Apple — App Store Connect

1. Apple Developer Program membership (€99/yr); app record + bundle id.
2. **Agreements, Tax, and Banking → sign the Paid Apps agreement.** IAP is inert
   until this is signed.
3. One **Auto-Renewable Subscription Group** ("mitlist Premium") — both durations
   in the same group so users can switch tiers.
4. Two subscription products in the group:
   - `me.mitlist.premium.monthly` — price = `€M`.
   - `me.mitlist.premium.yearly` — price = `€Y + €2`.
   - Each: localized display name, description, review screenshot.
5. No App Store `.p8` key is stored by the current implementation: signed
   StoreKit transactions and notifications verify locally. Add a key later only
   if App Store Server API reconciliation/status calls are implemented.
6. **App Store Server Notifications V2** production + sandbox URLs →
   `POST /webhooks/apple`.
7. One **Sandbox tester** account (Users and Access → Sandbox).
8. Copy the app's numeric **Apple ID** from App Information into
   `APPLE_IAP_APP_ID`; it is checked on production notification envelopes.

### Google — Play Console

1. Play Developer account ($25 one-time) + Payments profile (merchant).
2. One **subscription** `premium` with two **base plans** (auto-renewing):
   - `premium-monthly` — price = `€M`.
   - `premium-yearly` — price = `€Y + €2`.
3. **Service account** with Google Play Developer API access; download its JSON
   key. In Play Console grant only the app-level permission to view financial
   data, orders, and cancellation survey responses; this verifier only performs
   read-only subscription status calls.
4. **Real-Time Developer Notifications**: create a Pub/Sub topic, grant
   `google-play-developer-notifications@system.gserviceaccount.com` Publisher on
   it, and point an authenticated push subscription at `POST /webhooks/google`.
   Configure its OIDC audience and service-account email as
   `GOOGLE_PUBSUB_AUDIENCE` / `GOOGLE_PUBSUB_SERVICE_ACCOUNT`.
5. **License testers** (Play Console → Setup → License testing) for sandbox.

### Product-ID ↔ interval map (single source of truth)

| Interval | Apple product id                              | Google (sub / base plan)      |
|----------|-----------------------------------------------|-------------------------------|
| monthly  | `me.mitlist.premium.monthly`                  | `premium` / `premium-monthly` |
| yearly   | `me.mitlist.premium.yearly`                   | `premium` / `premium-yearly`  |

---

## 4. Backend changes (Go)

### 4.1 Config (`internal/config/config.go`)

The implemented environment variables are:

```
AppleIAPBundleID       string `env:"APPLE_IAP_BUNDLE_ID"`
AppleIAPEnvironment    string `env:"APPLE_IAP_ENVIRONMENT" default:"Production"`
AppleIAPAppID          int    `env:"APPLE_IAP_APP_ID"`
GooglePlayPackageName  string `env:"GOOGLE_PLAY_PACKAGE_NAME"`
GooglePlayServiceAccount string `env:"GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"`
AppleIAPProductMonthly string `env:"APPLE_IAP_PRODUCT_MONTHLY"`
AppleIAPProductYearly  string `env:"APPLE_IAP_PRODUCT_YEARLY"`
GooglePlaySubscriptionID string `env:"GOOGLE_PLAY_SUBSCRIPTION_ID"`
GooglePlayProductMonthly string `env:"GOOGLE_PLAY_PRODUCT_MONTHLY"`
GooglePlayProductYearly  string `env:"GOOGLE_PLAY_PRODUCT_YEARLY"`
GooglePubSubAudience string `env:"GOOGLE_PUBSUB_AUDIENCE"`
GooglePubSubServiceAccount string `env:"GOOGLE_PUBSUB_SERVICE_ACCOUNT"`
```

Like Polar, IAP is opt-in: unset Apple creds ⇒ Apple verification disabled,
unset Google creds ⇒ Google disabled. Add both to the "disabled features"
report near line 225.

### 4.2 Provider clients (new packages)

- `internal/services/appstore/` — verifies a StoreKit 2 signed transaction (JWS),
  and (optionally) calls the App Store Server API `Get Transaction Info` /
  `Get All Subscription Statuses` to fetch authoritative renewal state. Verifies
  JWS x5c chain against Apple root certs. Mirror `polar.Client`: `New(...)`,
  `Enabled()`, `APIError`.
- `internal/services/playstore/` — OAuth2 via service account, calls
  `androidpublisher.purchases.subscriptionsv2.get(packageName, token)` to verify
  a Google purchase token and read its line items / expiry / state.

Both expose a normalized result the service can turn into a
`models.BillingSubscription` (status, interval, amount, currency, period end,
cancel-at-period-end, provider subscription id).

### 4.3 Service (`internal/services/billing_service.go`)

New methods (entitlement logic untouched):

- `VerifyAppleTransaction(ctx, userID, groupID, signedTx) (*BillingSubscription, error)`
- `VerifyGooglePurchase(ctx, userID, groupID, productID, token) (*BillingSubscription, error)`
  Both: verify with the provider client → build a `models.BillingSubscription`
  (`Provider: "apple"|"google"`, `PrimaryGroupID: groupID`) → `repo.UpsertSubscription`.
  Guard double-subscribe: if `GetLiveSubscriptionForUser` already returns a live
  sub for a *different* provider, return a `ConflictError` the app renders as
  "you already subscribe on <web/other store>".
- `ApplyAppleNotification(ctx, notificationUUID, signedPayload) error`
- `ApplyGoogleNotification(ctx, messageID, rtdnPayload) error`
  Both mirror `ApplyWebhookEvent`: mark delivery id in `billing_webhook_events`
  for idempotency, decode, re-verify against the provider, upsert. Reuse
  `resolveUser`/`resolveGroup` semantics — user comes from `appAccountToken`
  (Apple) / `obfuscatedExternalAccountId` (Google), group from the same token or
  a purchase→group table (see 4.5).

Resolve **interval** from product id via the config map, since Apple/Google
report duration differently than Polar's `recurring_interval`.

### 4.4 Handlers (`internal/api/handlers/billing.go` + new webhook handlers)

Add to `RegisterRoutes`:
```
r.Post("/billing/iap/verify", h.VerifyIAP)     // authed; called by the app post-purchase
```
New unauthenticated (signature-verified) handlers, alongside `polar_webhook.go`:
```
POST /webhooks/apple   // ASSN V2 — verify JWS, then ApplyAppleNotification
POST /webhooks/google  // authenticated Pub/Sub push — verify OIDC, then ApplyGoogleNotification
```

`VerifyIAP` request:
```json
{ "platform": "apple|google", "product_id": "...", "token": "...", "group_id": "..." }
```
(`token` = StoreKit signed transaction on iOS, purchase token on Android.)

### 4.5 Tying a purchase to a mitlist user + household

The web flow stamps `external_customer_id = userID` and `metadata.group_id`
(`StartCheckout`). The IAP equivalent:
- **User**: set `appAccountToken` (Apple) / `obfuscatedAccountId` (Google) to the
  mitlist user UUID at purchase time in the app. Server-side notifications then
  resolve the user without trusting a client call.
- **Group**: the store token carries no room for our group id reliably. Simplest
  approach — the app's `POST /billing/iap/verify` passes `group_id`, and the
  server persists a `(provider_subscription_id → group_id)` association at first
  verify; later notifications keep the existing `primary_group_id` (same
  "only-set-if-unset" rule as `resolveGroup`). If the app is offline at renewal,
  the group is already stored, so notifications never need it.

### 4.6 Migration

No schema change strictly required — `provider` and the unique key already
generalize. Optional `000039_add_iap_fields`: nullable `store_environment TEXT`
(sandbox vs production) and `original_transaction_id TEXT` (Apple's stable
cross-renewal id) if you want cleaner Apple bookkeeping. Defer unless needed.

---

## 5. Frontend changes (Flutter)

### 5.1 Dependency

Add `in_app_purchase: ^3.x` to `pubspec.yaml` (official Flutter team package;
wraps StoreKit + Play Billing). No RevenueCat.

### 5.2 New service `lib/services/iap_service.dart`

- Query `ProductDetails` for the two store product ids (localized price string).
- `buy(interval, groupId)` → set `applicationUserName`/`appAccountToken` to the
  mitlist user id → `InAppPurchase.instance.buyNonConsumable(...)`.
- Listen to `purchaseStream`; on `purchased`/`restored`, send the receipt/token
  to `POST /billing/iap/verify`, then `completePurchase`, then `invalidateBilling`.
- `restorePurchases()` — required by Apple review.

### 5.3 `lib/sheets/premium_sheet.dart` — platform branch

Current `_startCheckout` always does Polar `launchUrl`. Branch on platform:
- Web / desktop / self-host build → keep Polar `launchUrl` (unchanged).
- iOS / Android → `IapService.buy(...)`; on success the purchase stream drives
  `invalidateBilling` + pop.
Show the store `ProductDetails.price` in `_IntervalSelector` on mobile instead of
`status.planFor(...)`. Keep the Polar price on web.

### 5.4 Manage / restore

- Add a **Restore purchases** button (mobile only).
- "Manage subscription": mobile deep-links to the system UI
  (`https://apps.apple.com/account/subscriptions` / Play
  `https://play.google.com/store/account/subscriptions?sku=...&package=...`);
  web keeps the existing Polar portal (`openPortal`).

### 5.5 Tests

Extend `frontend/test/billing_models_test.dart`; add an `iap_service` test with a
fake `InAppPurchase` that emits a purchase and asserts the verify call + refresh.

---

## 6. Edge cases and guards

- **Double subscribe** (web Polar *and* mobile IAP): `GetUserSubscription`
  already returns any live sub. The sheet must render "manage" not "buy" for a
  user who already has *any* live provider, and `VerifyIAP` must 409 a second
  provider. Otherwise a user pays twice with no extra benefit.
- **Server-authoritative**: never grant premium on the client's word — only after
  verify/notification confirms. The purchase stream success just triggers the
  verify round-trip.
- **Downgrade correctness**: handle Apple `DID_CHANGE_RENEWAL_STATUS`, `EXPIRED`,
  `REFUND`, `GRACE_PERIOD_EXPIRED`; Google `SUBSCRIPTION_CANCELED`,
  `SUBSCRIPTION_EXPIRED`, `SUBSCRIPTION_REVOKED`, `..._IN_GRACE_PERIOD`. Each maps
  to a `status` the existing `IsLive` check already understands.
- **Cross-platform mismatch**: an Apple purchase can't be managed from Android —
  fine, entitlement is per mitlist user server-side. Just don't offer a "buy"
  button to someone already covered.
- **Refund clawback**: refund notifications must flip status so `IsLive` returns
  false and the household loses growth headroom (existing members never evicted —
  `EnsureCanAddMember` only gates *new* members).

---

## 7. Testing

- Apple: sandbox tester + StoreKit config file for local; verify ASSN V2 hits the
  endpoint (Apple sends a "test notification" you can trigger from ASC).
- Google: license tester; use the Play Console "test" purchases and RTDN test
  message. Verify `subscriptionsv2.get` returns the expected state.
- Confirm the +€2 annual shows the correct localized string on-device (the store
  is the source of truth here, not the backend).
- Confirm a self-host build (no Apple/Google creds, no Polar) still shows no
  paywall — `BillingStatus.disabled` path.

---

## 9. What's left: store setup, native config, testing

The code is in place. These steps are yours (they can't be done from the repo):

### 9.1 Native platform capability config
- **iOS (Xcode)**: In-App Purchase is already enabled in the Xcode project.
  Open `frontend/ios/Runner.xcworkspace`, select the Runner target, choose your
  Apple development team, and confirm the capability/provisioning profile. For
  local testing add a StoreKit configuration file (`.storekit`) mirroring the
  two products and select it in the run scheme.
- **Android**: the `com.android.vending.BILLING` permission is added by the
  `in_app_purchase_android` plugin — nothing to add by hand. Publish to at least
  the **internal testing** track before subscriptions resolve (draft alone won't
  serve products).

### 9.2 Product-id sync (three places must match)
`IapConfig` (`frontend/lib/config/iap_config.dart`) · the backend env
(`APPLE_IAP_PRODUCT_*`, `GOOGLE_PLAY_PRODUCT_*`) · the store consoles. Change one,
change all three.

### 9.3 Secret and signing-key storage
- Backend deployment secret manager (never Flutter defines or git):
  `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`. Keep the JSON as a single secret value;
  inject the remaining `APPLE_IAP_*`, `GOOGLE_PLAY_*`, and `GOOGLE_PUBSUB_*`
  identifiers as normal deployment environment configuration. The Pub/Sub OIDC
  service account itself does not need a downloaded key on the backend.
- Local backend development only: use gitignored `backend/.env`, copied from
  `backend/.env.example`.
- Android upload signing: keep the `.jks` outside the repository and put its
  path/passwords in gitignored `frontend/android/key.properties` (see
  `key.properties.example`). In CI, store the base64 keystore and passwords in
  the CI secret manager and materialize them only for the build.
- iOS signing certificates and provisioning profiles: manage them through
  Xcode/Keychain or encrypted CI signing storage. There is no Apple IAP `.p8`
  key in this implementation.
- `TERMS_URL` and `PRIVACY_URL` are public Flutter `--dart-define` values, not
  secrets. They may be baked into release builds.

### 9.4 iOS receipt format checkpoint
The pinned `in_app_purchase_storekit` implementation enables StoreKit 2 by
default and exposes the transaction's JWS as `serverVerificationData`, which is
what the backend verifies. Still exercise this path on a real sandbox device
before shipping; the app intentionally does not support a StoreKit 1 receipt.

### 9.5 Sandbox testing
- iOS: a Sandbox tester (App Store Connect → Users and Access → Sandbox); sign
  into the sandbox account on-device; trigger a purchase; confirm
  `/billing/iap/verify` records it and premium activates. Use ASC's "request a
  test notification" to exercise `/webhooks/apple`.
- Android: a license tester; internal-testing build; test purchase; confirm the
  RTDN reaches `/webhooks/google` and the re-fetch records the sub.

## 8. Resolved implementation decisions

1. Bundle id and Android package: `me.mitlist`.
2. Canonical product ids: the §3 table.
3. No extra migration: the existing provider-scoped subscription key is enough.
4. Both clients are implemented; store rollout order remains an operational choice.
5. Store prices remain a console decision: monthly should match web and annual
   should be web annual +€2, using the store's available EUR price points.
