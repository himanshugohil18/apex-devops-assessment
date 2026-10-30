#!/usr/bin/env bash
set -Eeuo pipefail

NEW_VERSION="${1:-}"
ENV_FILE=".env"

if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Usage: ./scripts/release.sh MAJOR.MINOR.PATCH"
    exit 1
fi

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

CURRENT_VERSION="$(get_env APP_VERSION)"
CURRENT_VERSION="${CURRENT_VERSION:-1.0.0}"

if [[ "$NEW_VERSION" == "$CURRENT_VERSION" ]]; then
    echo "Version $NEW_VERSION is already configured."
    exit 1
fi

if ! docker image inspect "apex-operations-api:$CURRENT_VERSION" >/dev/null 2>&1; then
    echo "ERROR: Current image is unavailable."
    exit 1
fi

echo "Building version $NEW_VERSION..."
docker build -t "apex-operations-api:$NEW_VERSION" .

CHECK_CONTAINER="apex-api-check-${NEW_VERSION//./-}"

if docker container inspect "$CHECK_CONTAINER" >/dev/null 2>&1; then
    echo "ERROR: Temporary validation container already exists."
    exit 1
fi

echo "Validating new image..."
docker run -d --name "$CHECK_CONTAINER" \
    "apex-operations-api:$NEW_VERSION" >/dev/null

cleanup() {
    docker rm -f "$CHECK_CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

VALIDATED=false

for attempt in {1..15}; do
    if docker exec "$CHECK_CONTAINER" python -c \
        "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"; then
        VALIDATED=true
        break
    fi
    sleep 2
done

if [[ "$VALIDATED" != "true" ]]; then
    echo "ERROR: New image failed validation. Existing deployment unchanged."
    exit 1
fi

cleanup
trap - EXIT

echo "New image validated successfully."

set_env PREVIOUS_VERSION "$CURRENT_VERSION"
set_env APP_VERSION "$NEW_VERSION"

echo "Deploying $NEW_VERSION..."

if docker compose up -d --no-build --no-deps api && wait_healthy; then
    echo "Release successful: $NEW_VERSION"
    exit 0
fi

echo "ERROR: New release failed. Restoring $CURRENT_VERSION..."
set_env APP_VERSION "$CURRENT_VERSION"

if docker compose up -d --no-build --no-deps api && wait_healthy; then
    echo "Previous version restored and healthy: $CURRENT_VERSION"
else
    echo "CRITICAL: Automatic restoration failed."
    echo "APP_VERSION is set to $CURRENT_VERSION in .env."
    exit 2
fi

exit 1
