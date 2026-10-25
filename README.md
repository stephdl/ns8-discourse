# ns8-discourse

[Discourse](https://www.discourse.org/) community forum for [NethServer 8](https://github.com/NethServer/ns8-core).

The module runs the official `discourse/discourse` image, with PostgreSQL (`discourse/postgres`, which ships the `hstore`, `pg_trgm` and `vector` extensions) and Redis in the same rootless pod.
Traefik publishes it on a dedicated host name and always redirects HTTP to HTTPS.

Features:

- a local administrator account is created from NS8, no email is needed to activate it
- login with Discourse local accounts, and optionally with an external OpenID Connect provider such as Keycloak
- email notifications through the cluster smarthost, when it is configured
- default forum language and sender address chosen at configuration time
- backup, restore, clone and move

The NS8 settings reach Discourse as `DISCOURSE_*` environment variables.
Discourse locks those settings in its own admin page: change them from the NS8 Settings page.

## Install

Instantiate the module with:

    add-module ghcr.io/stephdl/discourse:latest 1

The output of the command will return the instance name.
Output example:

    {"module_id": "discourse1", "image_name": "discourse", "image_url": "ghcr.io/stephdl/discourse:latest"}

## Configure

Let's assume that the instance is named `discourse1`.

Launch `configure-module` with these parameters:

- `host`: fully qualified host name of the forum, like `forum.example.org`
- `lets_encrypt`: request a Let's Encrypt certificate (true/false)
- `admin_username`: username of the local administrator, 3 to 20 characters
- `admin_email`: email of the local administrator
- `admin_password`: password of the local administrator. Required at the first configuration, omit it to keep the current one. Discourse wants at least 15 characters for an administrator
- `default_locale`: Discourse locale code, like `en`, `fr`, `it` or `pt_BR`
- `notification_email`: sender address of the forum emails, empty means `noreply@<host>`
- `oidc_enabled`: enable the login with an OpenID Connect provider (true/false)
- `oidc_discovery_url`: the provider `.well-known/openid-configuration` address
- `oidc_client_id`: the client ID registered in the provider
- `oidc_client_secret`: the client secret. Required when OpenID Connect is enabled the first time, omit it to keep the current one

Example:

```
api-cli run configure-module --agent module/discourse1 --data - <<EOF
{
  "host": "forum.example.org",
  "lets_encrypt": true,
  "admin_username": "admin",
  "admin_email": "admin@example.org",
  "admin_password": "Very-l0ng-Passw0rd!",
  "default_locale": "en",
  "notification_email": "",
  "oidc_enabled": false
}
EOF
```

The first start runs the database migrations and builds the assets: it takes one to two minutes.
Then the configure step creates or updates the administrator account.

Retrieve the configuration with:

    api-cli run get-configuration --agent module/discourse1

## OpenID Connect

Register Discourse in the provider as a confidential client, with this redirect URI:

    https://<host>/auth/oidc/callback

The Settings page shows the exact URI.
Users get a Discourse account at their first login, with the name and email given by the provider.
Local accounts keep working, so the NS8 administrator account can always log in, even when the provider is down.

Discourse refuses to fetch documents from private addresses.
The module allows the host of the discovery URL, so a provider on the LAN works.

## Email

Discourse sends emails through the cluster smarthost, when it is configured.
Without it, users cannot sign up nor reset their password.
A change of the smarthost restarts the application.

## Backup, restore, clone

The backup contains a dump of the database, the secrets (database password, Rails secret key, OpenID Connect secret) and the `discourse-shared` volume (uploads and Discourse own backups).
The `discourse-shared` volume can be placed on an additional disk at install time.
Redis holds only caches and job queues: it is not backed up.

Let's Encrypt is disabled after a restore or a move, because the host may not resolve publicly on the new node.
Enable it again from the Settings page.

A cloned instance keeps the host name of its source and gets no Traefik route.
A restored instance gets no route either when another application still uses its host name.
Set a new host name from the Settings page to make it reachable.
A moved instance keeps its host name.

## Upgrade

The Discourse image runs the database migrations at startup when its version changes.
Back up the instance before an upgrade to a new Discourse series.
Renovate opens the image update PRs. Discourse stays on its ESR line (`YYYY.M.P` tags), and a new series is not merged automatically.
The About page shows the Discourse version next to the module version.

## Debug

Show the module environment:

    runagent -m discourse1 env

Show the settings passed to Discourse:

    runagent -m discourse1 podman exec discourse-app cat /var/www/discourse/config/discourse.conf

Run a Rails console:

    runagent -m discourse1 podman exec -ti -u discourse -w /var/www/discourse discourse-app bundle exec rails console

Read the Rails log:

    runagent -m discourse1 podman exec discourse-app tail -f /shared/log/rails/production.log

## Uninstall

To uninstall the instance:

    remove-module --no-preserve discourse1

## Testing

Test the module using the `test-module.sh` script:

    ./test-module.sh <NODE_ADDR> ghcr.io/stephdl/discourse:latest

The tests are made using [Robot Framework](https://robotframework.org/).

## UI translation

The UI is translated in English, French, Italian, German, Spanish, Portuguese, Brazilian Portuguese and Basque.
The source file is `ui/public/i18n/en/translation.json`.
