package models

// HomeMeal is a meal-plan row enriched with the recipe the Home screen needs
// to render its title. Recipe is nil when it was removed or is no longer
// readable; clients already degrade that state to a generic meal label.
type HomeMeal struct {
	Plan   MealPlan `json:"plan"`
	Recipe *Recipe  `json:"recipe,omitempty"`
}

// HomeSnapshot contains the independently cached sections rendered on Home.
// Optional section failures are reported alongside an empty value so a
// transient problem in one card does not hide the household itself.
type HomeSnapshot struct {
	Group          *Group          `json:"group"`
	Activities     []ActivityEvent `json:"activities"`
	ActivityError  bool            `json:"activity_error"`
	PinwallPosts   []PinwallPost   `json:"pinwall_posts"`
	PinwallError   bool            `json:"pinwall_error"`
	TodayMeals     []HomeMeal      `json:"today_meals"`
	TodayMealError bool            `json:"today_meal_error"`
}
