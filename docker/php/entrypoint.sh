#!/bin/sh
set -eu

UPLOADS="${BEDROCK_UPLOADS_DIR:-/var/www/html/web/app/uploads}"
CONFIG_DIR="${BEDROCK_CONFIG_DIR:-/var/www/html/.config}"
SALTS_FILE="${CONFIG_DIR}/salts.env"
DOTENV_SRC="${BEDROCK_DOTENV_FILE:-/run/dotenv}"
DOTENV_DEST="/var/www/html/.env"

mkdir -p "$UPLOADS" "$CONFIG_DIR"

if [ "$(id -u)" = "0" ]; then
  owner="$(stat -c %u "$UPLOADS" 2>/dev/null || echo 0)"
  if [ "$owner" = "0" ]; then
    chown www-data:www-data "$UPLOADS"
    chmod 775 "$UPLOADS"
  fi
  chown www-data:www-data "$CONFIG_DIR"
  chmod 775 "$CONFIG_DIR"
fi

# Dokploy / Compose write .env next to docker-compose.yml. Copy it in so
# Bedrock's phpdotenv loader (and ${WP_HOME} interpolation) works as upstream.
if [ -f "$DOTENV_SRC" ]; then
  cp "$DOTENV_SRC" "$DOTENV_DEST"
  if [ "$(id -u)" = "0" ]; then
    chown www-data:www-data "$DOTENV_DEST"
    chmod 640 "$DOTENV_DEST"
  fi
fi

is_placeholder() {
  [ -z "${1:-}" ] || [ "$1" = "generateme" ]
}

if is_placeholder "${DB_PASSWORD:-}"; then
  i=0
  while [ ! -s "$CONFIG_DIR/db_password" ]; do
    i=$((i + 1))
    if [ "$i" -gt 90 ]; then
      echo "Timed out waiting for DB password file" >&2
      exit 1
    fi
    sleep 1
  done
  DB_PASSWORD="$(cat "$CONFIG_DIR/db_password")"
  export DB_PASSWORD
fi

export DB_NAME="${DB_NAME:-wordpress}"
export DB_USER="${DB_USER:-wordpress}"

if [ -n "${WP_HOME:-}" ]; then
  case "${WP_SITEURL:-}" in
    ''|*'${WP_HOME}'*)
      export WP_SITEURL="${WP_HOME}/wp"
      ;;
  esac
fi

if is_placeholder "${AUTH_KEY:-}"; then
  if [ -f "$SALTS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$SALTS_FILE"
  else
    echo "Generating persistent WordPress salts..."
    AUTH_KEY="$(php -r 'echo bin2hex(random_bytes(32));')"
    SECURE_AUTH_KEY="$(php -r 'echo bin2hex(random_bytes(32));')"
    LOGGED_IN_KEY="$(php -r 'echo bin2hex(random_bytes(32));')"
    NONCE_KEY="$(php -r 'echo bin2hex(random_bytes(32));')"
    AUTH_SALT="$(php -r 'echo bin2hex(random_bytes(32));')"
    SECURE_AUTH_SALT="$(php -r 'echo bin2hex(random_bytes(32));')"
    LOGGED_IN_SALT="$(php -r 'echo bin2hex(random_bytes(32));')"
    NONCE_SALT="$(php -r 'echo bin2hex(random_bytes(32));')"
    umask 077
    cat > "$SALTS_FILE" <<EOF
export AUTH_KEY=${AUTH_KEY}
export SECURE_AUTH_KEY=${SECURE_AUTH_KEY}
export LOGGED_IN_KEY=${LOGGED_IN_KEY}
export NONCE_KEY=${NONCE_KEY}
export AUTH_SALT=${AUTH_SALT}
export SECURE_AUTH_SALT=${SECURE_AUTH_SALT}
export LOGGED_IN_SALT=${LOGGED_IN_SALT}
export NONCE_SALT=${NONCE_SALT}
EOF
    if [ "$(id -u)" = "0" ]; then
      chown www-data:www-data "$CONFIG_DIR" "$SALTS_FILE"
    fi
  fi
  export AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY
  export AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT
fi

if [ "${COMPOSER_AUTO_INSTALL:-0}" = "1" ] && [ ! -f /var/www/html/vendor/autoload.php ]; then
  echo "Composer dependencies missing; installing..."
  composer install --prefer-dist --no-interaction --no-progress --optimize-autoloader
fi

exec docker-php-entrypoint "$@"
