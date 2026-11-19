# Load balancing and traffic weights

[All demos](../../README.md) · Source: [demo.exs](demo.exs)

Balance requests across two endpoints with `ROUND_ROBIN`, sample the traffic
distribution, switch to `LEAST_REQUEST` live, and experiment with weighted splits
across separate clusters.

## Drive in `arionctl shell`

```elixir
Demo.open(:load_balancing)
Demos.LoadBalancing.round_robin()
Demos.LoadBalancing.sample(6)         # prints per-backend hit counts

Demos.LoadBalancing.least_request()
Demos.LoadBalancing.sample(6)

Demos.LoadBalancing.weighted(90, 10)
Demos.LoadBalancing.sample(20)

Demos.LoadBalancing.weighted(50, 50)  # try any weights you like
Demos.LoadBalancing.sample(20)
```

Or run unattended with `Demo.run(:load_balancing)`.
