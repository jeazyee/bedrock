<p align="center">
  <a href="https://roots.io/bedrock/">
    <img alt="Bedrock" src="https://cdn.roots.io/app/uploads/logo-bedrock.svg" height="100">
  </a>
</p>

<p align="center">
  <a href="https://packagist.org/packages/roots/bedrock"><img alt="Packagist Installs" src="https://img.shields.io/packagist/dt/roots/bedrock?label=projects%20created&colorB=2b3072&colorA=525ddc&style=flat-square"></a>
  <a href="https://packagist.org/packages/roots/wordpress"><img alt="roots/wordpress Packagist Downloads" src="https://img.shields.io/packagist/dt/roots/wordpress?label=roots%2Fwordpress%20downloads&logo=roots&logoColor=white&colorB=2b3072&colorA=525ddc&style=flat-square"></a>
  <img src="https://img.shields.io/badge/dynamic/json.svg?url=https://raw.githubusercontent.com/roots/bedrock/master/composer.json&label=wordpress&logo=roots&logoColor=white&query=$.require[%22roots/wordpress%22]&colorB=2b3072&colorA=525ddc&style=flat-square">
  <a href="https://github.com/roots/bedrock/actions/workflows/ci.yml"><img alt="Build Status" src="https://img.shields.io/github/actions/workflow/status/roots/bedrock/ci.yml?branch=master&logo=github&label=CI&style=flat-square"></a>
  <a href="https://twitter.com/rootswp"><img alt="Follow Roots" src="https://img.shields.io/badge/follow%20@rootswp-1da1f2?logo=twitter&logoColor=ffffff&message=&style=flat-square"></a>
  <a href="https://github.com/sponsors/roots"><img src="https://img.shields.io/badge/sponsor%20roots-525ddc?logo=github&style=flat-square&logoColor=ffffff&message=" alt="Sponsor Roots"></a>
</p>

<p align="center">WordPress boilerplate with Composer, easier configuration, and an improved folder structure</p>

<p align="center">
  <a href="https://roots.io/bedrock/">Website</a> &nbsp;&nbsp; <a href="https://roots.io/bedrock/docs/installation/">Documentation</a> &nbsp;&nbsp; <a href="https://github.com/roots/bedrock/releases">Releases</a> &nbsp;&nbsp; <a href="https://discourse.roots.io/">Community</a>
</p>

## Support us

Roots is an independent open source org, supported only by developers like you. Your sponsorship funds [WP Packages](https://wp-packages.org/) and the entire Roots ecosystem, and keeps them independent. Support us by purchasing [Radicle](https://roots.io/radicle/) or [sponsoring us on GitHub](https://github.com/sponsors/roots) — sponsors get access to our private Discord.

### Sponsors

<a href="https://carrot.com/"><img src="https://cdn.roots.io/app/uploads/carrot.svg" alt="Carrot" height="90"></a> <a href="https://wordpress.com/"><img src="https://cdn.roots.io/app/uploads/wordpress.svg" alt="WordPress.com" height="90"></a> <a href="https://www.itineris.co.uk/"><img src="https://cdn.roots.io/app/uploads/itineris.svg" alt="Itineris" height="90"></a> <a href="https://kinsta.com/?kaid=OFDHAJIXUDIV"><img src="https://cdn.roots.io/app/uploads/kinsta.svg" alt="Kinsta" height="90"></a>

## Overview

Bedrock is a WordPress boilerplate for developers that want to manage their projects with Git and Composer. Much of the philosophy behind Bedrock is inspired by the [Twelve-Factor App](http://12factor.net/) methodology, including the [WordPress specific version](https://roots.io/twelve-factor-wordpress/).

- Better folder structure
- Dependency management with [Composer](https://getcomposer.org)
  - [`roots/wordpress`](https://wp-packages.org/wordpress-core) package for WordPress core
  - [WP Packages](https://wp-packages.org/) repository for WordPress plugins and themes
- Easy WordPress configuration with environment specific files
- Environment variables with [Dotenv](https://github.com/vlucas/phpdotenv)
- Autoloader for mu-plugins (use regular plugins as mu-plugins)

## Local development

```sh
cp .env.example .env
docker compose -f docker-compose.dev.yml up -d
```

The first start builds PHP-FPM with the WordPress extensions, installs Composer dependencies, and serves the site at [http://localhost:8080](http://localhost:8080). MariaDB and Redis persist in Docker volumes across `docker compose down` / `up`. Uploads are stored in `web/app/uploads`. Use `docker compose down -v` only when you intend to wipe database and cache data.

```sh
docker compose -f docker-compose.dev.yml exec php wp core install \
  --url=http://localhost:8080 \
  --title=Bedrock \
  --admin_user=admin \
  --admin_password=admin \
  --admin_email=admin@example.com \
  --skip-email
```

Generate new salts at [https://roots.io/salts.html](https://roots.io/salts.html) before anything public-facing, or leave `AUTH_KEY=generateme` and let the container generate persistent salts into `.config/`.

## Production (Dokploy)

Dokploy's **Environment** tab *is* the `.env` file. On every deploy it writes that file next to `docker-compose.yml` and Compose loads it. You never create or edit `.env` on the server.

This repo is meant to be deployed as a **Docker Compose** application (not Docker Stack). Leave the compose path as `./docker-compose.yml`.

1. Create a Compose service in Dokploy, type **Docker Compose**, and point it at this repository.
2. In **Environment**, set:

```
WP_HOME=https://your-domain
```

   Database passwords and WordPress salts are generated on first boot and stored on the `config` volume.
3. In **Domains**, add the same hostname on the `web` service, port `80`.
4. If a previous deploy failed, delete the compose volumes (`db_data` and `config`) once so MariaDB can initialize cleanly, then deploy again.
5. Enable **Volume Backups** for `db_data`, `uploads`, and `config`. Do not enable Isolated Deployments unless you also remove the external `dokploy-network` block.

Named volumes (`db_data`, `uploads`, `redis_data`, `config`) survive AutoDeploy.

## Getting Started

See the [Bedrock installation documentation](https://roots.io/bedrock/docs/installation/).

## Community

Keep track of development and community news.

- Join us on Discord by [sponsoring us on GitHub](https://github.com/sponsors/roots)
- Join us on [Roots Discourse](https://discourse.roots.io/)
- Follow [@rootswp on Twitter](https://twitter.com/rootswp)
- Follow the [Roots Blog](https://roots.io/blog/)
- Subscribe to the [Roots Newsletter](https://roots.io/subscribe/)
