package push

import (
	"encoding/json"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
)

// The refresh push must never show anything: no notification block, and a
// background (not alert) push on iOS.
func TestWidgetRefreshMessageIsSilent(t *testing.T) {
	group := uuid.MustParse("11111111-1111-4111-8111-111111111111")
	encoded, err := json.Marshal(widgetRefreshMessage("device-token", group))
	require.NoError(t, err)
	require.JSONEq(t, `{"message":{
		"token":"device-token",
		"data":{"type":"widget_refresh","group_id":"11111111-1111-4111-8111-111111111111"},
		"android":{"collapse_key":"widgets:11111111-1111-4111-8111-111111111111","priority":"normal"},
		"apns":{
			"headers":{"apns-push-type":"background","apns-priority":"5","apns-collapse-id":"widgets:11111111-1111-4111-8111-111111111111"},
			"payload":{"aps":{"content-available":1}}
		}
	}}`, string(encoded))
}
