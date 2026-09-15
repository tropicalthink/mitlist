package handlers

import (
	"context"
	"html/template"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/onboarding"
)

// tipsOptOutStore is the one write the unsubscribe link performs.
type tipsOptOutStore interface {
	SetTipsEmailsEnabled(ctx context.Context, userID uuid.UUID, enabled bool) error
}

// EmailUnsubscribeHandler serves the link in the onboarding emails' footer
// and List-Unsubscribe header. It is public: the HMAC token in the query is
// the credential, since the person clicking is in their mail client, not
// signed in to the app.
type EmailUnsubscribeHandler struct {
	cfg   *config.Config
	store tipsOptOutStore
}

func NewEmailUnsubscribeHandler(cfg *config.Config, store tipsOptOutStore) *EmailUnsubscribeHandler {
	return &EmailUnsubscribeHandler{cfg: cfg, store: store}
}

// RegisterRoutes mounts the endpoint. GET is the footer link a person clicks;
// POST is RFC 8058 one-click, which Gmail and the like send without showing
// the person a page. Both do the same thing.
func (h *EmailUnsubscribeHandler) RegisterRoutes(r chi.Router) {
	r.Get("/email/unsubscribe", h.Unsubscribe)
	r.Post("/email/unsubscribe", h.Unsubscribe)
	r.Get("/email/assets/{filename}", h.Hero)
}

// Hero serves a campaign's embedded static illustration. It contains no recipient
// identifier or tracking parameter and is safe for public, long-lived caches.
func (h *EmailUnsubscribeHandler) Hero(w http.ResponseWriter, r *http.Request) {
	data, ok := onboarding.HeroImage(chi.URLParam(r, "filename"))
	if !ok {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "image/jpeg")
	w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(data)
}

// Unsubscribe turns the tips series off for the account named by the token.
// It answers 200 with the same page for a valid token and for one that names
// a since-deleted account, and 400 only for a token that fails the MAC; there
// is nothing to enumerate either way, since a token cannot be guessed.
func (h *EmailUnsubscribeHandler) Unsubscribe(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	if !middleware.CheckLimit("email-unsubscribe:"+middleware.ExtractIP(r), 20, 20.0/600) {
		w.Header().Set("Retry-After", "60")
		http.Error(w, "Please wait a moment and try again.", http.StatusTooManyRequests)
		return
	}
	userID, ok := onboarding.ParseUnsubscribeToken([]byte(h.cfg.SecretKey), r.URL.Query().Get("token"))
	if !ok {
		h.render(w, http.StatusBadRequest, unsubscribePage{
			Title: "That link did not work",
			Body:  "The unsubscribe link is incomplete or has been altered. Open the email again and use the link at the bottom, or turn tips off in the app under You.",
		})
		return
	}
	if err := h.store.SetTipsEmailsEnabled(r.Context(), userID, false); err != nil {
		http.Error(w, "Something went wrong on our side. Please try again in a minute.", http.StatusInternalServerError)
		return
	}
	h.render(w, http.StatusOK, unsubscribePage{
		Title: "You're unsubscribed",
		Body:  "No more tips from mitlist. Account emails, like a password reset you ask for, still arrive. Changed your mind? Turn tips back on in the app under You.",
	})
}

type unsubscribePage struct {
	Title string
	Body  string
	App   string
}

func (h *EmailUnsubscribeHandler) render(w http.ResponseWriter, status int, page unsubscribePage) {
	page.App = h.cfg.FrontendURL
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	_ = unsubscribeTemplate.Execute(w, page)
}

// The page borrows the emails' desk so the click lands somewhere that looks
// like where it came from.
var unsubscribeTemplate = template.Must(template.New("unsubscribe").Parse(`<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>{{.Title}} · mitlist</title>
<style>
  body { margin:0; background:#f7f4ec; font-family:'Space Grotesk',Helvetica,Arial,sans-serif; color:#1a1714; }
  .wrap { max-width:560px; margin:0 auto; padding:48px 16px; }
  .mark { display:flex; align-items:center; gap:10px; font-weight:700; font-size:24px; letter-spacing:-0.03em; margin-bottom:18px; }
  .mark i { width:14px; height:14px; background:#f97316; border:2px solid #1a1714; display:inline-block; }
  .card { background:#fffcf7; border:2px solid #1a1714; box-shadow:7px 7px 0 #1a1714; padding:34px 36px 30px; }
  h1 { margin:0 0 12px; font-size:32px; line-height:36px; letter-spacing:-0.03em; }
  p { margin:0; font-size:16px; line-height:24px; color:#453d36; }
  a.btn { display:inline-block; margin-top:26px; background:#f97316; border:2px solid #1a1714; box-shadow:5px 5px 0 #1a1714; padding:12px 22px; font-weight:700; color:#1a1714; text-decoration:none; }
</style>
</head>
<body>
<div class="wrap">
  <div class="mark"><i></i>mitlist</div>
  <div class="card">
    <h1>{{.Title}}</h1>
    <p>{{.Body}}</p>
    {{if .App}}<a class="btn" href="{{.App}}">Open mitlist &rarr;</a>{{end}}
  </div>
</div>
</body>
</html>
`))
