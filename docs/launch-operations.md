# Public beta operational gate

The public beta is ready only after every applicable item is verified against
the deployed service, not merely present in source code.

## Availability and recovery

- [ ] Monitor the landing page, web app, API, authentication, PostgreSQL,
      attachments, email, push delivery, jobs, docs, and feedback board from an
      independent system.
- [ ] Measure PostgreSQL replication lag and document whether commits are
      synchronous or asynchronous.
- [ ] Exercise application failover without losing confirmed writes.
- [ ] Encrypt database backups, run them twice daily, and enforce a rolling
      maximum retention of 30 days.
- [ ] Restore a database backup into an isolated environment and verify it.
- [ ] Create an independent, versioned copy of R2 attachments with separate
      credentials and a 30-day old-version lifecycle.
- [ ] Reconcile PostgreSQL attachment metadata against both object stores.
- [ ] Alert on backup failure, replication lag, object-copy failure, storage
      quota pressure, certificate expiry, and failed scheduled jobs.
- [ ] Document the real RPO/RTO after the restore and failover exercises.

## Privacy and security

- [ ] Configure GlitchTip with tracing disabled and a maximum 30-day retention.
- [ ] Verify event scrubbing using a synthetic exception.
- [ ] Verify Cloudflare Web Analytics is limited to the marketing site.
- [ ] Verify `hi@`, `support@`, `privacy@`, `legal@`, and `security@mitlist.me`.
- [ ] Publish `/.well-known/security.txt` and test it from the public origin.
- [ ] Obtain final review of the German terms, privacy notice, and imprint.
- [ ] Record deletion and restore procedures, including reapplying deletions
      before a restored service is reopened.

## Product and billing

- [ ] Verify public registration at `app.mitlist.me`.
- [ ] Verify €3.99 monthly and €29.99 yearly prices in Polar, App Store
      Connect, and Google Play Console, including regional tax presentation.
- [ ] Verify that every feature remains available below the member paywall.
- [ ] Test the fourth-to-fifth-member Premium gate.
- [ ] Test subscription cancellation, renewal, lapse, restore, and moving the
      covered household.
- [ ] Verify TestFlight and Google Play invitation instructions end to end.
- [ ] Replace every `data-launch-placeholder` screenshot before official launch.

## Communications

- [ ] Publish `docs.mitlist.me` and `status.mitlist.me` before linking them live.
- [ ] Proofread all five homepage languages with fluent speakers.
- [ ] Verify localized metadata, canonical URLs, `hreflang`, sitemap, and social card.
- [ ] Keep beta invitations and optional launch-news consent separate.
