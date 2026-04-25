-- Recreate Vault and LivingThings tables dropped in 000004.
-- Note: This restores schema only; it cannot restore deleted data.

CREATE TABLE vault_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    reminder_date TIMESTAMPTZ,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE vault_shares (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vault_item_id UUID NOT NULL REFERENCES vault_items(id) ON DELETE CASCADE,
    shared_with_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    permission TEXT NOT NULL DEFAULT 'view',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (vault_item_id, shared_with_user_id)
);

CREATE TABLE living_things (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    species TEXT NOT NULL,
    location TEXT NOT NULL DEFAULT '',
    image_url TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE care_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    living_thing_id UUID NOT NULL REFERENCES living_things(id) ON DELETE CASCADE,
    frequency_value INTEGER NOT NULL,
    frequency_unit TEXT NOT NULL,
    next_due TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE care_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    care_schedule_id UUID NOT NULL REFERENCES care_schedules(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notes TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE species_wiki (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    common_name TEXT NOT NULL,
    scientific_name TEXT NOT NULL,
    care_instructions TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_vault_items_group_id ON vault_items(group_id);
CREATE INDEX idx_vault_items_created_by ON vault_items(created_by);
CREATE INDEX idx_vault_shares_vault_item_id ON vault_shares(vault_item_id);
CREATE INDEX idx_living_things_group_id ON living_things(group_id);
CREATE INDEX idx_care_schedules_living_thing_id ON care_schedules(living_thing_id);
CREATE INDEX idx_care_logs_care_schedule_id ON care_logs(care_schedule_id);

