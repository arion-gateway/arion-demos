# Role-based access control (RBAC)

[All demos](../../README.md) · Source: [demo.exs](demo.exs)

Allow public requests under `/public` and restrict other paths with an HTTP RBAC
filter, then update the required role live over xDS.

> Note: This demo uses a plain request header for simplicity. In production,
> derive identity from verified credentials before evaluating RBAC rules.

## Drive in `arionctl shell`

```elixir
Demo.open(:rbac)
Demos.Rbac.setup()
Demo.get("/public/hello")                                 # 200
Demo.get("/admin")                                        # 403
Demo.get("/admin", headers: [{"x-demo-role", "admin"}])   # 200

Demos.Rbac.allow_role("operator")
Demo.get("/admin", headers: [{"x-demo-role", "admin"}])     # now 403
Demo.get("/admin", headers: [{"x-demo-role", "operator"}])  # 200
```

Or run unattended with `Demo.run(:rbac)`.
