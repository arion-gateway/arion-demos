defmodule Demos.Routing do
  @moduledoc "Prefixes, headers, query params, rewrites, redirects, and 404s."

  alias Arion.ControlPlane.Helpers.{
    Cluster,
    FilterChain,
    Hcm,
    Listener,
    Route,
    RouteConfig,
    VirtualHost
  }

  def steps do
    [
      {:setup, "Demos.Routing.setup()", "Start backend-a & backend-b, attach Listener to RDS demo-routes"},
      {:add_prefix_rewrite, "Demos.Routing.add_prefix_rewrite()", "Route /api -> backend-a with / rewrite and x-demo-proxy header"},
      {:add_header_and_query, "Demos.Routing.add_header_and_query()", "Route x-demo-backend: b or ?backend=b -> backend-b"},
      {:add_redirects_and_direct, "Demos.Routing.add_redirects_and_direct()", "Add /old -> 302 /api, /health -> 200, and 404 fallback"}
    ]
  end

  def run do
    setup()
    add_prefix_rewrite()
    Demo.get("/api/hello")
    add_header_and_query()
    Demo.get("/hello", headers: [{"x-demo-backend", "b"}])
    Demo.get("/hello?backend=b")
    add_redirects_and_direct()
    Demo.get("/old")
    Demo.get("/health")
    Demo.get("/unknown")
  end

  def setup do
    Demo.reset()
    Demo.start_backend(18081, "backend-a")
    Demo.start_backend(18082, "backend-b")

    cluster_a = Cluster.static("backend", "127.0.0.1", [18081], connect_timeout: 1)
    cluster_b = Cluster.static("backend-b", "127.0.0.1", [18082], connect_timeout: 1)

    routes =
      RouteConfig.new("demo-routes")
      |> RouteConfig.add_virtual_host(
        VirtualHost.new("all")
        |> VirtualHost.add_route(
          Route.new() |> Route.match_prefix("/") |> Route.to_cluster("backend")
        )
      )

    hcm = Hcm.new(codec_type: :HTTP1) |> Demo.rds("demo-routes")

    listener =
      Listener.new("http", Listener.local_address(18080))
      |> Listener.add_filter_chain(FilterChain.new("http") |> FilterChain.add_hcm(hcm))

    Demo.apply!(cluster: cluster_a, cluster: cluster_b, route: routes, listener: listener)

    Demo.hint([
      ~s|Demo.get("/")|,
      "Demo.show(:routing, :add_prefix_rewrite)",
      "Demos.Routing.add_prefix_rewrite()"
    ])
  end

  def add_prefix_rewrite do
    vh = VirtualHost.new("all") |> VirtualHost.add_route(api_route())
    Demo.apply!(route: RouteConfig.new("demo-routes") |> RouteConfig.add_virtual_host(vh))

    Demo.hint([
      ~s|Demo.get("/api/hello") # rewritten to /hello + x-demo-proxy|,
      "Demo.show(:routing, :add_header_and_query)",
      "Demos.Routing.add_header_and_query()"
    ])
  end

  def add_header_and_query do
    vh =
      VirtualHost.new("all")
      |> VirtualHost.add_route(api_route())
      |> VirtualHost.add_route(header_route())
      |> VirtualHost.add_route(query_route())

    Demo.apply!(route: RouteConfig.new("demo-routes") |> RouteConfig.add_virtual_host(vh))

    Demo.hint([
      ~s|Demo.get("/hello", headers: [{"x-demo-backend", "b"}])|,
      ~s|Demo.get("/hello?backend=b")|,
      "Demo.show(:routing, :add_redirects_and_direct)",
      "Demos.Routing.add_redirects_and_direct()"
    ])
  end

  def add_redirects_and_direct do
    vh =
      VirtualHost.new("all")
      |> VirtualHost.add_route(api_route())
      |> VirtualHost.add_route(header_route())
      |> VirtualHost.add_route(query_route())
      |> VirtualHost.add_route(
        Route.new("old")
        |> Route.match_prefix("/old")
        |> Route.redirect(scheme: false, path_redirect: "/api", response_code: :FOUND)
      )
      |> VirtualHost.add_route(
        Route.new("health")
        |> Route.match_prefix("/health")
        |> Route.direct_response(200, Route.data_source(:inline_string, "Arion is ready\n"))
      )
      |> VirtualHost.add_route(
        Route.new("fallback")
        |> Route.match_prefix("/")
        |> Route.direct_response(404, Route.data_source(:inline_string, "No matching route\n"))
      )

    Demo.apply!(route: RouteConfig.new("demo-routes") |> RouteConfig.add_virtual_host(vh))

    Demo.hint([
      ~s|Demo.get("/old")        # 302 Location: /api|,
      ~s|Demo.get("/health")     # 200 Arion is ready|,
      ~s|Demo.get("/unknown")    # 404 No matching route|
    ])
  end

  defp api_route do
    Route.new("api")
    |> Route.match_prefix("/api")
    |> Route.to_cluster("backend")
    |> Route.prefix_rewrite("/")
    |> Route.add_response_header(
      Route.header_update(:append_if_exists_or_add, Route.header_value("x-demo-proxy", "arion"))
    )
  end

  defp header_route do
    match =
      Route.match_prefix("/")
      |> Route.add_header(Route.header_match(:exact, "x-demo-backend", "b"))

    Route.new("header-b") |> Route.put_match(match) |> Route.to_cluster("backend-b")
  end

  defp query_route do
    match =
      Route.match_prefix("/")
      |> Route.add_query(Route.query_match("backend", Route.string_matcher(:exact, "b")))

    Route.new("query-b") |> Route.put_match(match) |> Route.to_cluster("backend-b")
  end
end
