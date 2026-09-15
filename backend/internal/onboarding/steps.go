package onboarding

import (
	"strings"
	"time"
)

// SendWindow is how long after its due time a step may still go out. A person
// who signed up months before the series existed is past every window and
// gets nothing; a step the job could not deliver on the hour it came due is
// retried for a few days and then dropped rather than arriving weeks late.
const SendWindow = 72 * time.Hour

// Step is one email in the series.
type Step struct {
	// Key names the step in the send ledger. Stable: renaming one would
	// re-send it to everyone still inside its window.
	Key string
	// After is the delay from account creation.
	After   time.Duration
	Subject string
	// Eyebrow is the small chip above the heading ("Day 3").
	Eyebrow string
	Heading string
	Intro   string
	Tips    []Tip
	// HeroFilename selects the embedded static illustration for this step;
	// HeroAlt describes the linked image to screen-reader users.
	HeroFilename string
	HeroAlt      string
	// CTA is the button. Path is relative to the web app origin.
	CTALabel string
	CTAPath  string
}

// MaxTips caps how much one email asks of a person. Three things to try is
// a nudge; more is a manual nobody reads.
const MaxTips = 3

// Tip is one titled paragraph in the body of a step. Each one links straight
// to the screen where the reader can do what it describes, so the tip is a
// button and not just a description.
type Tip struct {
	Title string
	Body  string
	// Path is where the tip opens, relative to the web app origin.
	Path string
}

// Steps is the series, in order. Timings are the usual retention curve: the
// first nudge before the first day is out, then when the novelty has worn off
// (day 3), then weekly, then a one-month check-in. Every email is about
// something the person has not necessarily found yet, and says how to find it.
var Steps = []Step{
	{
		Key:     "day1-household",
		After:   20 * time.Hour,
		Subject: "A household of one is just a to-do list",
		Eyebrow: "Day 1",
		Heading: "Get the others in",
		Intro:   "mitlist works when the people you live with are in it too. Everything you add shows up on their phones the moment you add it, and the other way round.",
		Tips: []Tip{
			{Title: "Send one invite link", Body: "Open your household, tap Invite, and share the link in your house group chat. Anyone who opens it lands in your household, no codes to type.", Path: "/home"},
			{Title: "Start with the shopping list", Body: "It is the easiest habit to build together. One shared list, and whoever is in the shop just ticks things off.", Path: "/lists"},
		},
		HeroFilename: "day1-household.jpg",
		HeroAlt:      "Invite your housemates and start one shared shopping list",
		CTALabel:     "Open your household",
		CTAPath:      "/home",
	},
	{
		Key:     "day3-lists",
		After:   3 * 24 * time.Hour,
		Subject: "Never text \"do we need milk?\" again",
		Eyebrow: "Day 3",
		Heading: "Lists that keep up with you",
		Intro:   "A few things the shopping list does that are easy to miss.",
		Tips: []Tip{
			{Title: "Sorted by aisle", Body: "Pick the store you shop at and the list groups itself the way the shop is laid out, so you stop walking back for the onions.", Path: "/you/shopping-locations"},
			{Title: "Scan a paper note", Body: "The scanner reads a handwritten list straight into the app. It runs on your phone; nothing is uploaded.", Path: "/scanner"},
			{Title: "From meal plan to list", Body: "Plan the week's dinners and send the ingredients to the shopping list in one tap.", Path: "/recipes/meal-plan"},
		},
		HeroFilename: "day3-lists.jpg",
		HeroAlt:      "Scan a paper list, sort it by aisle, and add meal-plan ingredients",
		CTALabel:     "Open your lists",
		CTAPath:      "/lists",
	},
	{
		Key:     "day7-money",
		After:   7 * 24 * time.Hour,
		Subject: "Who owes what, without the awkward chat",
		Eyebrow: "Week 1",
		Heading: "Split the bills once, then forget them",
		Intro:   "Shared money is where most households get tense. mitlist keeps a running balance so nobody has to bring it up.",
		Tips: []Tip{
			{Title: "Add an expense, pick a split", Body: "Equal, by share, or exact amounts. Everyone involved sees it and the balances update straight away.", Path: "/money"},
			{Title: "Rent, internet, streaming", Body: "Set an expense to repeat monthly and it books itself. No one has to remember the first of the month.", Path: "/money/recurring"},
			{Title: "Settle up", Body: "When someone pays another back, record it and the balance goes to zero. Snap a receipt onto any expense for later.", Path: "/money"},
		},
		HeroFilename: "day7-money.jpg",
		HeroAlt:      "Split expenses, repeat bills, and settle household balances",
		CTALabel:     "Open money",
		CTAPath:      "/money",
	},
	{
		Key:     "day14-chores",
		After:   14 * 24 * time.Hour,
		Subject: "Chores that rotate themselves",
		Eyebrow: "Week 2",
		Heading: "Stop being the one who reminds everyone",
		Intro:   "Set up the recurring jobs once and let the app do the nagging.",
		Tips: []Tip{
			{Title: "Rotation", Body: "Put the bins, the bathroom, the kitchen on a schedule and choose who is in the rotation. mitlist assigns the next person each time and reminds them.", Path: "/chores"},
			{Title: "The pinwall", Body: "For everything that is not a chore: notes for the house, the wifi password, a reminder that the plumber comes Thursday. Notes can carry reminders.", Path: "/home"},
			{Title: "Your calendar, your way", Body: "Chores, meals and pinwall dates all show up on the calendar tab, and you can export them to the calendar app you already use.", Path: "/calendar"},
		},
		HeroFilename: "day14-chores.jpg",
		HeroAlt:      "Rotate recurring chores and send automatic reminders",
		CTALabel:     "Open chores",
		CTAPath:      "/chores",
	},
	{
		Key:     "day30-checkin",
		After:   30 * 24 * time.Hour,
		Subject: "One month in: a few things you may have missed",
		Eyebrow: "Month 1",
		Heading: "Make it yours",
		Intro:   "You have had mitlist for a month. Three more things worth a look.",
		Tips: []Tip{
			{Title: "Recipes from anywhere", Body: "Paste a link to a recipe and mitlist imports it, ingredients and all. Plan it for a day and the ingredients are one tap from the shopping list.", Path: "/recipes"},
			{Title: "A weekly summary, if you want one", Body: "Turn on the weekly digest under notifications and get one email a week with what happened in the household. Off by default.", Path: "/you/notification-preferences"},
			{Title: "Tell us what is missing", Body: "The feedback board is where features come from. If something is clumsy, say so; we read all of it.", Path: "/you/feature-board"},
		},
		HeroFilename: "day30-checkin.jpg",
		HeroAlt:      "Discover recipes, weekly summaries, smart-home tools, and feedback",
		CTALabel:     "Open mitlist",
		CTAPath:      "/home",
	},
}

// Due reports the steps whose send time falls inside [now-SendWindow, now]
// for an account created at createdAt. Callers still consult the ledger;
// this only says what the calendar allows.
func Due(createdAt, now time.Time) []Step {
	var due []Step
	for _, s := range Steps {
		at := createdAt.Add(s.After)
		if at.After(now) {
			continue
		}
		if now.Sub(at) > SendWindow {
			continue
		}
		due = append(due, s)
	}
	return due
}

// StepByKey finds a step by its ledger key.
func StepByKey(key string) (Step, bool) {
	for _, s := range Steps {
		if s.Key == key {
			return s, true
		}
	}
	return Step{}, false
}

// joinURL glues an origin and a path without doubling the slash.
func joinURL(origin, path string) string {
	return strings.TrimRight(origin, "/") + "/" + strings.TrimLeft(path, "/")
}
