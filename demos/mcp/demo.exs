defmodule Demos.Mcp do
  @moduledoc "Expose HTTP endpoints as MCP tools and drive a session step by step."

  alias Arion.ControlPlane.Helpers.{
    Cluster,
    FilterChain,
    Hcm,
    Listener,
    McpGateway,
    Route,
    RouteConfig,
    VirtualHost
  }

  @mcp_headers [
    {"content-type", "application/json"},
    {"accept", "application/json, text/event-stream"}
  ]

  def steps do
    [
      {:setup, "Demos.Mcp.setup()", "Start backend-a and publish MCP gateway with demo.greet"},
      {:connect, "session = Demos.Mcp.connect()", "Initialize an MCP session and bind its session ID"},
      {:list_tools, "Demos.Mcp.list_tools(session)", "Query tools/list on your session"},
      {:call_tool, ~s|Demos.Mcp.call_tool(session, "demo.greet", %{"name" => "Ada"})|, "Invoke an MCP tool with arguments you choose"},
      {:add_echo_tool, "Demos.Mcp.add_echo_tool()", "Publish a second tool (demo.echo) live over xDS"}
    ]
  end

  def run do
    setup()
    session = connect()
    list_tools(session)
    call_tool(session, "demo.greet", %{"name" => "Ada"})
    add_echo_tool()
    session = connect()
    list_tools(session)
    call_tool(session, "demo.echo", %{"text" => "hello over xDS"})
  end

  def setup do
    Demo.reset()
    Demo.start_backend(18081, "backend-a")

    cluster = Cluster.static("backend", "127.0.0.1", [18081], connect_timeout: 1)
    Demo.apply!(cluster: cluster, listener: mcp_listener([greet_tool()]))

    Demo.hint([
      "Demo.show(:mcp, :connect) # optional: inspect handshake",
      "session = Demos.Mcp.connect()"
    ])
  end

  def connect do
    init =
      Demo.post(
        "/mcp",
        %{
          jsonrpc: "2.0",
          id: 1,
          method: "initialize",
          params: %{
            protocolVersion: "2025-03-26",
            capabilities: %{},
            clientInfo: %{name: "arion-demo", version: "1.0.0"}
          }
        },
        headers: @mcp_headers
      )

    session =
      Enum.find_value(init.headers, fn {k, v} ->
        if String.downcase(k) == "mcp-session-id", do: v
      end) || raise("missing Mcp-Session-Id header")

    Demo.post(
      "/mcp",
      %{jsonrpc: "2.0", method: "notifications/initialized"},
      headers: session_headers(session)
    )

    Demo.hint([
      "Demos.Mcp.list_tools(session)",
      ~s|Demos.Mcp.call_tool(session, "demo.greet", %{"name" => "Ada"})|
    ])

    session
  end

  def list_tools(session) when is_binary(session) do
    resp =
      Demo.post(
        "/mcp",
        %{jsonrpc: "2.0", id: 2, method: "tools/list", params: %{}},
        headers: session_headers(session)
      )

    Demo.hint([
      ~s|Demos.Mcp.call_tool(session, "demo.greet", %{"name" => "Ada"})|,
      "Demos.Mcp.add_echo_tool()"
    ])

    resp
  end

  def call_tool(session, name \\ "demo.greet", arguments \\ %{"name" => "Ada"})
      when is_binary(session) do
    resp =
      Demo.post(
        "/mcp",
        %{jsonrpc: "2.0", id: 3, method: "tools/call", params: %{name: name, arguments: arguments}},
        headers: session_headers(session)
      )

    Demo.hint([
      ~s|Demos.Mcp.call_tool(session, "demo.greet", %{"name" => "Grace"})|,
      "Demos.Mcp.add_echo_tool()"
    ])

    resp
  end

  def add_echo_tool do
    Demo.apply!(listener: mcp_listener([greet_tool(), echo_tool()]))

    Demo.hint([
      "session = Demos.Mcp.connect() # fresh session after Listener update",
      "Demos.Mcp.list_tools(session)",
      ~s|Demos.Mcp.call_tool(session, "demo.echo", %{"text" => "hello"})|
    ])
  end

  defp session_headers(session), do: [{"mcp-session-id", session} | @mcp_headers]

  defp greet_tool do
    McpGateway.tool(
      "demo",
      "greet",
      "Greet someone using a local HTTP backend.",
      McpGateway.rest_backend("backend", "GET", "/greet", query_params: [{"name", "name"}]),
      disclosure: :eager,
      input_schema: ~s({"type":"object","properties":{"name":{"type":"string"}},"required":["name"]})
    )
  end

  defp echo_tool do
    McpGateway.tool(
      "demo",
      "echo",
      "Echo a text message through the local HTTP backend.",
      McpGateway.rest_backend("backend", "GET", "/echo", query_params: [{"text", "text"}]),
      disclosure: :eager,
      input_schema: ~s({"type":"object","properties":{"text":{"type":"string"}},"required":["text"]})
    )
  end

  defp mcp_listener(tools) do
    gateway = McpGateway.gateway("arion-demo", upstream_timeout: 5, tools: tools)

    routes =
      RouteConfig.new("demo-routes")
      |> RouteConfig.add_virtual_host(
        VirtualHost.new("all")
        |> VirtualHost.add_route(
          Route.new() |> Route.match_prefix("/") |> Route.to_cluster("backend")
        )
      )

    hcm =
      Hcm.new(codec_type: :HTTP1)
      |> Hcm.route_config(routes)
      |> Hcm.add_filter(McpGateway.filter("arion.filters.http.mcp", gateway))

    Listener.new("http", Listener.local_address(18080))
    |> Listener.add_filter_chain(FilterChain.new("http") |> FilterChain.add_hcm(hcm))
  end
end
