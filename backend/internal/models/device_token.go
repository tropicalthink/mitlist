package models

import (
	"time"

	"github.com/google/uuid"
)

// DeviceToken holds an FCM registration token for a mobile device.
type DeviceToken struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	Platform  string    `json:"platform"` // "android" | "ios"
	Token     string    `json:"token"`
	CreatedAt time.Time `json:"created_at"`
}
