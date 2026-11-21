# Development

[Back to the demo index](../README.md).

## Overriding container images

`docker-compose.yml` pulls `ghcr.io/arion-gateway/arion:1.0.0` and
`ghcr.io/arion-gateway/arion-ctl:1.0.0` by default. Override either image or host port:

```sh
ARION_IMAGE=ghcr.io/arion-gateway/arion:1.0.0 \
ARION_CTL_IMAGE=ghcr.io/arion-gateway/arion-ctl:1.0.0 \
DEMO_HTTP_PORT=28080 DEMO_TLS_PORT=28443 \
  docker compose up -d
```

## Running with local binaries (no Docker)

If you have local builds of `arion` and `arion-ctl` in sibling checkouts:

```sh
(cd ../arion && cargo build --locked -p arion-proxy --features access-log)
(cd ../arion-ctl/apps/arion_ctl && mix deps.get --check-locked && MIX_ENV=prod mix release)

./scripts/local.sh start
./scripts/local.sh shell
```

Override binary paths with `ARION_BIN` and `ARION_CTL_BIN` if needed. Inspect logs
with `./scripts/local.sh logs proxy` (or `control`) and stop with `./scripts/local.sh stop`.

## Smoke-testing all demos

Inside `arionctl shell`:

```elixir
Demo.run_all()
```
