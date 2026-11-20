# Retries and timeouts

[All demos](../../README.md) · Source: [demo.exs](demo.exs)

Retry `5xx` responses against `/flaky` and enforce a `100ms` timeout on `/slow`,
then adjust the route timeout live in milliseconds over RDS.

## Drive in `arionctl shell`

```elixir
Demo.open(:traffic)
Demos.Traffic.setup()
Demo.get("/flaky?example=1")            # 200 on attempt 2 (Arion retried 503)
Demo.get("/slow")                       # 504 after 100ms

Demos.Traffic.set_slow_timeout(2_000)   # relax timeout to 2000ms live
Demo.get("/slow")                       # 200 after ~1s
```

Or run unattended with `Demo.run(:traffic)`.
