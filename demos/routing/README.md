# Routing

[All demos](../../README.md) · Source: [demo.exs](demo.exs)

Attach a listener to an RDS `RouteConfiguration` and incrementally publish path
prefix rewrites, response headers, header/query matchers, redirects, direct
responses, and a 404 fallback.

## Drive in `arionctl shell`

```elixir
Demo.open(:routing)
Demos.Routing.setup()
Demos.Routing.add_prefix_rewrite()
Demo.get("/api/hello")                                  # rewritten to /hello + x-demo-proxy

Demos.Routing.add_header_and_query()
Demo.get("/hello", headers: [{"x-demo-backend", "b"}])  # -> "backend-b"
Demo.get("/hello?backend=b")                            # -> "backend-b"

Demos.Routing.add_redirects_and_direct()
Demo.get("/old")                                        # 302 Location: /api
Demo.get("/health")                                     # 200 Arion is ready
Demo.get("/unknown")                                    # 404 No matching route
```

Use `Demo.show(:routing, :add_prefix_rewrite)` to inspect any step, `Demo.hint()` to
re-show the nudge, or `Demo.run(:routing)` to run all steps unattended.
