# MCP gateway

[All demos](../../README.md) · Source: [demo.exs](demo.exs)

Expose local HTTP endpoints as MCP tools, open a Streamable HTTP session, list and
invoke tools with your own arguments, and publish an additional tool live over xDS.

## Drive in `arionctl shell`

```elixir
Demo.open(:mcp)
Demos.Mcp.setup()                                        # 1. publish demo.greet tool
session = Demos.Mcp.connect()                            # 2. initialize MCP session
Demos.Mcp.list_tools(session)                            # 3. tools/list
Demos.Mcp.call_tool(session, "demo.greet", %{"name" => "Ada"})

Demos.Mcp.add_echo_tool()                                # 5. add demo.echo live over xDS
session = Demos.Mcp.connect()
Demos.Mcp.list_tools(session)
Demos.Mcp.call_tool(session, "demo.echo", %{"text" => "hello over xDS"})
```

Use `Demo.show(:mcp, :connect)` to read any step's source, `Demo.hint()` to re-show
the nudge, or `Demo.run(:mcp)` to run the full sequence unattended. Any external
Streamable HTTP MCP client can also connect directly to `http://localhost:18080/mcp`.
