#!/usr/bin/env bash
set -Eeuo pipefail

ENV_FILE=".env"

get_env() {
    grep -m1 "^$1=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- || true
}

set_env() {
    local key="$1"
    local value="$2"

    if grep -q "^${key}=" "$ENV_FILE"; then
        sed -i "s/^${key}=.*/${key}=${value}/" "$ENV_FILE"
    else
        printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
    fi
}

wait_healthy() {
    local container_id

    for attempt in {1..20}; do
        container_id="$(docker compose ps -q api 2>/dev/null || true)"

        if [[ -n "$container_id" ]]; then
            status="$(docker inspect \
                --format '{{.State.Health.Status}}' \
                "$container_id" 2>/dev/null || true)"

            if [[ "$status" == "healthy" ]]; then
                return 0
            fi
        fi

        sleep 3
    done

    return 1
}

if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: .env file not found."
    exit 1
fi

CURRENT_VERSION="$(get_env APP_VERSION)"
PREVIOUS_VERSION="$(get_env PREVIOUS_VERSION)"

if [[ -z "$CURRENT_VERSION" || -z "$PREVIOUS_VERSION" ]]; then
    echo "ERROR: Current or previous version is not configured."
    exit 1
fi

if ! docker image inspect "apex-operations-api:$PREVIOUS_VERSION" >/dev/null 2>&1; then
    echo "ERROR: Previous image is unavailable: $PREVIOUS_VERSION"
    exit 1
fi

echo "Current version: $CURRENT_VERSION"
echo "Rolling back to: $PREVIOUS_VERSION"

set_env APP_VERSION "$PREVIOUS_VERSION"

if docker compose up -d --no-build --no-deps api && wait_healthy; then
    set_env PREVIOUS_VERSION "$CURRENT_VERSION"
    echo "Rollback successful: $PREVIOUS_VERSION"
    echo "Previous release retained: $CURRENT_VERSION"
    exit 0
fi

echo "ERROR: Rollback target failed health validation."
echo "Restoring original version: $CURRENT_VERSION"

set_env APP_VERSION "$CURRENT_VERSION"

if docker compose up -d --no-build --no-deps api && wait_healthy; then
    echo "Original version restored and healthy: $CURRENT_VERSION"
    exit 1
fi

echo "CRITICAL: Original version could not be restored automatically."
exit 2
