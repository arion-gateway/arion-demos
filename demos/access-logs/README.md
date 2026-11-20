# Access logs

[All demos](../../README.md) · Source: [demo.exs](demo.exs)

Attach a `FileAccessLog` formatter writing one summary line per request to proxy
stdout, then customize the log format live over xDS.

## Drive in `arionctl shell`

```elixir
Demo.open(:access_logs)
Demos.AccessLogs.setup()
Demo.get("/hello")

Demos.AccessLogs.set_format("my-access %REQ(:METHOD)% %REQ(:PATH)% -> %RESPONSE_CODE%\n")
Demo.get("/another-request")
```

Or run unattended with `Demo.run(:access_logs)`. Inspect emitted log lines from your
host terminal:

```sh
docker compose logs --tail 20 arion
```
