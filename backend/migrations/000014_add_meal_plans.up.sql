-- Meal plans table for weekly meal planning
CREATE TABLE meal_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    slot TEXT NOT NULL DEFAULT 'dinner',
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    servings INTEGER NOT NULL DEFAULT 1,
    cook_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (group_id, date, slot)
);

CREATE INDEX idx_meal_plans_group_date ON meal_plans(group_id, date);
CREATE INDEX idx_meal_plans_recipe ON meal_plans(recipe_id);
