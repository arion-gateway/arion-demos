Code.require_file("lib/demo.exs")
Demo.load_all()

alias Arion.ControlPlane.Helpers.{
  AccessLog,
  Cluster,
  Endpoint,
  FilterChain,
  Hcm,
  Listener,
  McpGateway,
  Rbac,
  Route,
  RouteConfig,
  Secret,
  Tls,
  VirtualHost,
  Xds
}

Demo.banner()
