package models

import (
	"time"

	"github.com/google/uuid"
)

type LivingThing struct {
	ID        uuid.UUID `json:"id"`
	GroupID   uuid.UUID `json:"group_id"`
	Name      string    `json:"name"`
	Species   string    `json:"species"`
	Location  string    `json:"location"`
	ImageURL  string    `json:"image_url"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type CareSchedule struct {
	ID             uuid.UUID `json:"id"`
	LivingThingID  uuid.UUID `json:"living_thing_id"`
	FrequencyValue int       `json:"frequency_value"`
	FrequencyUnit  string    `json:"frequency_unit"`
	NextDue        time.Time `json:"next_due"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

type CareLog struct {
	ID             uuid.UUID `json:"id"`
	CareScheduleID uuid.UUID `json:"care_schedule_id"`
	UserID         uuid.UUID `json:"user_id"`
	Notes          string    `json:"notes"`
	CreatedAt      time.Time `json:"created_at"`
}

type SpeciesWiki struct {
	ID               uuid.UUID `json:"id"`
	CommonName       string    `json:"common_name"`
	ScientificName   string    `json:"scientific_name"`
	CareInstructions string    `json:"care_instructions"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
}
