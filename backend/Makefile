# =============================================================================
# mitlist — Go backend Makefile
# =============================================================================

APP_NAME    := mitlist
BUILD_DIR   := bin
MAIN_PKG    := ./cmd/api
MIGRATE_PKG := ./cmd/migrate

.PHONY: build test lint migrate-up migrate-down run docker-build

## build: Build the Go binary.
build:
	@echo "Building $(APP_NAME)..."
	@mkdir -p $(BUILD_DIR)
	go build -ldflags="-s -w" -o $(BUILD_DIR)/$(APP_NAME) $(MAIN_PKG)

## test: Run all tests.
test:
	mkdir -p $(BUILD_DIR)
	go test -v -race -coverprofile=$(BUILD_DIR)/coverage.out ./...
	@go tool cover -func=$(BUILD_DIR)/coverage.out | tail -n 1

## lint: Run golangci-lint.
lint:
	golangci-lint run ./...

## migrate-up: Run migrations up.
migrate-up:
	go run $(MIGRATE_PKG) up

## migrate-down: Run migrations down.
migrate-down:
	go run $(MIGRATE_PKG) down

## run: Run the application.
run:
	go run $(MAIN_PKG)

## docker-build: Build Docker image.
docker-build:
	docker build -t $(APP_NAME):latest .
