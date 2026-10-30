-- A password account created on a server with no email provider is signed in
-- without proving its address (is_verified is set so it can use the app). The
-- flag records that the address was only claimed, so OAuth sign-in never links
-- a Google/Apple identity to such an account by matching email: whoever typed
-- the address first would otherwise own the provider's account. It clears as
-- soon as an emailed code (verification or password reset) proves the address.
-- Every existing row was verified through email or a provider, hence FALSE.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS email_unproven BOOLEAN NOT NULL DEFAULT FALSE;
