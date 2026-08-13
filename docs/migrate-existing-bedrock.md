# Migrate an existing Bedrock project to this Dokploy stack

Use this guide to add the Docker / Dokploy deployment from this repository to a stock [Roots Bedrock](https://roots.io/bedrock/) project without replacing Bedrock itself.

The stack is additive. `config/application.php` stays Bedrock’s, plus one optional Redis block. Dokploy’s **Environment** tab is the project `.env` file.

## What you get

- Local: `docker compose -f docker-compose.dev.yml up -d` on port `8080`
- Production: Dokploy Compose (`docker-compose.yml`) with PHP-FPM, nginx, MariaDB, Redis, and a WP-Cron sidecar
- Same Bedrock `.env` locally and in Dokploy (`WP_HOME`, `WP_SITEURL`, `DB_*`, salts)

## Prerequisites

- Bedrock layout: `config/application.php`, `web/wp-config.php`, Composer WordPress install in `web/wp`
- PHP **8.3+** (the image is `php:8.3-fpm`). Older Bedrock (`php: >=8.1`) usually runs on 8.3; if it does not, change the `FROM` line in `Dockerfile`
- A Dokploy server with the external Docker network `dokploy-network` (Dokploy creates this by default)
- Do not enable **Isolated Deployments** in Dokploy unless you also remove the `dokploy-network` block from `docker-compose.yml`

## 1. Copy the Docker files

From this repository into the Bedrock project root:

```
Dockerfile
docker-compose.yml
docker-compose.dev.yml
docker/
```

Also copy `.dockerignore` if the project does not have one. If it does, merge at least:

```
.env
.env.*
!.env.example
auth.json
vendor
web/wp
web/app/uploads/*
!web/app/uploads/.gitkeep
web/app/cache
web/app/upgrade
web/app/object-cache.php
.config
docker-compose.override.yml
```

## 2. Ignore generated paths

Add to `.gitignore` if missing:

```
.config/
web/app/object-cache.php
docker-compose.override.yml
```

`web/app/uploads/*` and `.env` should already be ignored in Bedrock.

## 3. Enable Redis in Bedrock config

Compose sets `WP_REDIS_HOST=redis`. Bedrock only turns Redis on if those constants exist.

In `config/application.php`, immediately after the salt `Config::define` lines, add:

```php
/**
 * Redis object cache (phpredis). Enabled when WP_REDIS_HOST is set.
 */
if (env('WP_REDIS_HOST')) {
    Config::define('WP_CACHE', true);
    Config::define('WP_REDIS_CLIENT', 'phpredis');
    Config::define('WP_REDIS_HOST', env('WP_REDIS_HOST'));
    Config::define('WP_REDIS_PORT', env('WP_REDIS_PORT') ?: 6379);
    Config::define('WP_REDIS_DATABASE', env('WP_REDIS_DATABASE') ?: 0);
    Config::define('WP_REDIS_PREFIX', env('WP_REDIS_PREFIX') ?: 'bedrock:');
    Config::define('WP_REDIS_TIMEOUT', env('WP_REDIS_TIMEOUT') ?: 1);
    Config::define('WP_REDIS_READ_TIMEOUT', env('WP_REDIS_READ_TIMEOUT') ?: 1);
    Config::define('WP_REDIS_GRACEFUL', true);

    if (env('WP_REDIS_PASSWORD')) {
        Config::define('WP_REDIS_PASSWORD', env('WP_REDIS_PASSWORD'));
    }
}
```

Without `WP_REDIS_HOST` this is a no-op, so local non-Docker workflows keep working.

Dokploy terminates TLS at Traefik. If `application.php` does not already map `HTTP_X_FORWARDED_PROTO`, add (stock Bedrock already has this):

```php
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}
```

Do **not** add custom `WP_HOME` / `DB_PASSWORD` file loaders. Env vars from `.env` are enough.

## 4. Composer: Redis drop-in

The object-cache drop-in is copied from the Redis plugin after `composer install`.

In `composer.json`:

1. Require the plugin (WP Packages is already the Bedrock Composer repo):

```json
"wp-plugin/redis-cache": "^2.8"
```

2. Add the script and hook it after install/update. Keep any existing `post-install-cmd` / `post-update-cmd` entries:

```json
"scripts": {
    "enable-redis-cache": "@php docker/php/enable-redis-cache.php",
    "post-install-cmd": ["@enable-redis-cache"],
    "post-update-cmd": ["@enable-redis-cache"]
}
```

Then:

```sh
composer update wp-plugin/redis-cache --no-install
composer install
```

## 5. Keep using the project `.env`

Leave the existing `.env` / `.env.example`. Compose overrides `DB_HOST=database` and `WP_REDIS_HOST=redis` at runtime, so `DB_HOST=localhost` in `.env` is fine.

For local Docker, `WP_HOME` / `WP_SITEURL` should match the published port:

```
WP_HOME='http://localhost:8080'
WP_SITEURL="${WP_HOME}/wp"
```

`AUTH_KEY='generateme'` (and the other salts) is valid: the container generates persistent salts into `.config/` on first boot. Prefer real salts from [roots.io/salts.html](https://roots.io/salts.html) for anything public.

Optional production-only keys you can omit (the stack fills them in):

| Variable | If omitted |
| --- | --- |
| `DB_PASSWORD` | Generated on first boot and stored on the `config` volume |
| Salts (`AUTH_KEY`, …) | Generated into `.config/salts.env` |
| `WP_SITEURL` | Set to `${WP_HOME}/wp` |
| `WP_ENV` | `production` in `docker-compose.yml` |
| `DB_NAME` / `DB_USER` | `wordpress` |

If MariaDB has already been initialized, do not later add a **different** `DB_PASSWORD`. It is only applied on first database init.

## 6. Check locally

```sh
docker compose -f docker-compose.dev.yml up -d
```

The site is at [http://localhost:8080](http://localhost:8080).

Trellis, Valet, Herd, or another local stack can stay; this compose file does not replace them. Use one local runtime at a time so ports and `.env` URLs do not clash.

Import an existing local database if needed:

```sh
docker compose -f docker-compose.dev.yml exec php wp db import /var/www/html/dump.sql --allow-root
docker compose -f docker-compose.dev.yml exec php wp search-replace 'https://old-url' 'http://localhost:8080' --all-tables --allow-root
```

Uploads live in `web/app/uploads` on the bind mount in development.

## 7. Deploy on Dokploy

1. Push the branch that contains the Docker files.
2. Create a **Docker Compose** application (not Docker Stack). Compose path: `./docker-compose.yml`.
3. In **Environment**, paste the production `.env` — the same keys Bedrock already uses:

```
DB_NAME='wordpress'
DB_USER='wordpress'
DB_PASSWORD='choose-a-strong-password'
WP_ENV='production'
WP_HOME='https://your-domain'
WP_SITEURL="${WP_HOME}/wp"
AUTH_KEY='…'
SECURE_AUTH_KEY='…'
LOGGED_IN_KEY='…'
NONCE_KEY='…'
AUTH_SALT='…'
SECURE_AUTH_SALT='…'
LOGGED_IN_SALT='…'
NONCE_SALT='…'
```

   Minimum if you want generated secrets: `WP_HOME` and `WP_ENV=production`.

4. In **Domains**, attach the public hostname to the `web` service, port `80` (Traefik handles HTTPS).
5. Enable **Volume Backups** for `db_data`, `uploads`, and `config`.
6. Deploy.

If the first deploy fails halfway, delete volumes `db_data` and `config` once so MariaDB can initialize cleanly, then deploy again.

## 8. Move an existing production site

Do this after the new stack is up and you can reach `https://your-domain`.

1. On the old host, dump the database and copy `web/app/uploads`.
2. Load the dump into the new PHP container (adjust the service exec to however Dokploy exposes Compose):

```sh
wp db import dump.sql --allow-root
wp search-replace 'https://old-url' 'https://your-domain' --all-tables --allow-root
wp cache flush --allow-root
```

3. Copy uploads into the `uploads` volume (`web/app/uploads` in the PHP/nginx containers).
4. Confirm `WP_HOME` / `WP_SITEURL` in Dokploy Environment match the public URL.
5. Switch DNS to the Dokploy host.

WordPress serialized data must be rewritten with `wp search-replace`, not a plain text replace.

## 9. After cutover

- Remove Trellis / old host deploy keys only when DNS and backups are confirmed
- Keep Composer-managed plugins/themes in git as Bedrock already does; do not install from wp-admin (`DISALLOW_FILE_MODS` stays on in production)
- Named volumes (`db_data`, `uploads`, `redis_data`, `config`) survive AutoDeploy

## File checklist

| Path | Action |
| --- | --- |
| `Dockerfile` | Copy |
| `docker-compose.yml` | Copy |
| `docker-compose.dev.yml` | Copy |
| `docker/` | Copy |
| `.dockerignore` | Copy or merge |
| `.gitignore` | Add `.config/`, `object-cache.php`, `docker-compose.override.yml` |
| `config/application.php` | Add Redis block; keep HTTPS proxy snippet |
| `composer.json` | Add `wp-plugin/redis-cache` + `enable-redis-cache` script |
| `.env` / Dokploy Environment | Reuse existing Bedrock keys; set `WP_ENV=production` and public `WP_HOME` |
