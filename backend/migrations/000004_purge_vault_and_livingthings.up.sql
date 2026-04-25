-- Purge Vault and LivingThings features (data loss).
-- This migration drops all tables that exclusively belong to Vault and LivingThings.

DROP TABLE IF EXISTS care_logs;
DROP TABLE IF EXISTS care_schedules;
DROP TABLE IF EXISTS living_things;
DROP TABLE IF EXISTS species_wiki;

DROP TABLE IF EXISTS vault_shares;
DROP TABLE IF EXISTS vault_items;

