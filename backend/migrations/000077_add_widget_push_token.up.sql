-- iOS 26 WidgetKit push (plans/047, stage 7): a widget extension registers
-- its push token with its device's widget credential. Re-issuing the
-- credential carries the token over to the new row.
ALTER TABLE integration_credentials ADD COLUMN push_token TEXT;
