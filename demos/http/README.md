# HTTP basics

[All demos](../../README.md) · Source: [demo.exs](demo.exs)

Start an HTTP listener forwarding requests to a backend cluster, then switch the
cluster to another backend live over xDS without restarting the proxy.

## Drive in `arionctl shell`

```elixir
Demo.open(:http)
Demo.show(:http, :setup)                       # optional: read the source first
Demos.Http.setup()                             # 1. start backend-a + Cluster + Listener
Demo.get("/hello")                             # -> "backend-a"
Demos.Http.switch_backend(18082, "backend-b")  # 2. start backend-b & repoint Cluster live
Demo.get("/hello")                             # -> "backend-b"
```

Use `Demo.hint()` anytime to re-display the next-step nudge, or run unattended with
`Demo.run(:http)`.

From a host terminal:

```sh
curl http://localhost:18080/hello
```
