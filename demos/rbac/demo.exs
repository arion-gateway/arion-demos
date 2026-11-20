defmodule Demos.Rbac do
  @moduledoc "HTTP RBAC allow policies for public paths and role headers."

  alias Arion.ControlPlane.Helpers.{
    Cluster,
    FilterChain,
    Hcm,
    Listener,
    Rbac,
    Route,
    RouteConfig,
    VirtualHost
  }

  def steps do
    [
      {:setup, "Demos.Rbac.setup()", "Allow /public/* for everyone and all paths for x-demo-role: admin"},
      {:allow_role, ~s|Demos.Rbac.allow_role("operator")|, "Update the RBAC policy live to require a chosen role"}
    ]
  end

  def run do
    setup()
    Demo.get("/public/hello")
    Demo.get("/admin")
    Demo.get("/admin", headers: [{"x-demo-role", "admin"}])
    allow_role("operator")
    Demo.get("/admin", headers: [{"x-demo-role", "admin"}])
    Demo.get("/admin", headers: [{"x-demo-role", "operator"}])
  end

  def setup do
    Demo.reset()
    Demo.start_backend(18081, "backend-a")

    cluster = Cluster.static("backend", "127.0.0.1", [18081], connect_timeout: 1)
    Demo.apply!(cluster: cluster, listener: rbac_listener("admin"))

    Demo.hint([
      ~s|Demo.get("/public/hello") # 200|,
      ~s|Demo.get("/admin") # 403|,
      ~s|Demo.get("/admin", headers: [{"x-demo-role", "admin"}]) # 200|,
      ~s|Demos.Rbac.allow_role("operator")|
    ])
  end

  def allow_role(role \\ "operator") when is_binary(role) do
    Demo.apply!(listener: rbac_listener(role))

    Demo.hint([
      ~s|Demo.get("/admin", headers: [{"x-demo-role", "admin"}]) # 403|,
      ~s|Demo.get("/admin", headers: [{"x-demo-role", "#{role}"}]) # 200|
    ])
  end

  defp rbac_listener(role) do
    public_policy =
      Rbac.policy(
        [
          Rbac.header_permission(
            Route.header_match(:string, ":path", Route.string_matcher(:prefix, "/public"))
          )
        ],
        [Rbac.any_principal()]
      )

    role_policy =
      Rbac.policy(
        [Rbac.any_permission()],
        [Rbac.header_principal(Route.header_match(:exact, "x-demo-role", role))]
      )

    rbac_filter =
      Rbac.http_filter(
        "envoy.filters.http.rbac",
        Rbac.rules(:ALLOW, %{"public-path" => public_policy, "demo-admin" => role_policy}),
        ""
      )

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
      |> Hcm.add_filter(rbac_filter)

    Listener.new("http", Listener.local_address(18080))
    |> Listener.add_filter_chain(FilterChain.new("http") |> FilterChain.add_hcm(hcm))
  end
end
