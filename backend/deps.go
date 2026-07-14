package mitlist

import (
	_ "github.com/SherClockHolmes/webpush-go"
	_ "github.com/go-chi/chi/v5"
	_ "github.com/golang-jwt/jwt/v5"
	_ "github.com/google/uuid"
	_ "github.com/jackc/pgx/v5"
	_ "github.com/onsi/ginkgo/v2"
	_ "github.com/onsi/gomega"
	_ "github.com/robfig/cron/v3"
	_ "github.com/rs/zerolog"
	_ "github.com/stretchr/testify"
	_ "golang.org/x/crypto/bcrypt"
	_ "golang.org/x/oauth2"
)
