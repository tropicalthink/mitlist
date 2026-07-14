package models

import (
	"time"

	"github.com/google/uuid"
)

type AttachmentStatus string

const (
	AttachmentStatusPending AttachmentStatus = "pending"
	AttachmentStatusReady   AttachmentStatus = "ready"
	AttachmentStatusFailed  AttachmentStatus = "failed"
)

// Attachment is a file stored in S3-compatible object storage (e.g. Cloudflare R2).
// It is always associated with a group for authorization and quota enforcement.
type Attachment struct {
	ID                   uuid.UUID        `json:"id"`
	GroupID              uuid.UUID        `json:"group_id"`
	UserID               uuid.UUID        `json:"user_id"`
	Purpose              string           `json:"purpose"`
	ObjectKey            string           `json:"object_key"`
	ContentType          string           `json:"content_type"`
	ByteSize             int64            `json:"byte_size"`
	Status               AttachmentStatus `json:"status"`
	CreatedAt            time.Time        `json:"created_at"`
	ReservationExpiresAt *time.Time       `json:"-"`
}

// AttachmentStorageUsage is the household-level accounting snapshot used by
// operators to enforce quotas and by members to see how much space remains.
type AttachmentStorageUsage struct {
	UsedBytes     int64 `json:"used_bytes"`
	ReservedBytes int64 `json:"reserved_bytes"`
}
