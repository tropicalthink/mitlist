-- Revert meal plans
DROP INDEX IF EXISTS idx_meal_plans_group_date;
DROP INDEX IF EXISTS idx_meal_plans_recipe;
DROP TABLE IF EXISTS meal_plans;
