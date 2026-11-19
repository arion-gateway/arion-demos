# TLS termination

[All demos](../../README.md) · Source: [demo.exs](demo.exs)

Generate a self-signed certificate, publish it as an xDS `Secret`, terminate HTTPS
on port `18443` via SDS, and rotate the certificate live without restarting the
listener.

## Drive in `arionctl shell`

```elixir
Demo.open(:tls)
Demos.Tls.publish_secret()       # 1. generate cert + publish Secret "demo-cert"
Demos.Tls.publish_listener()     # 2. bind HTTPS Listener on :18443 via SDS
Demo.get("/hello", tls: true)    # verified against the generated demo cert
Demos.Tls.rotate_secret()        # 3. rotate "demo-cert" live over SDS
Demo.get("/hello", tls: true)    # verified against the rotated cert
```

Or run unattended with `Demo.run(:tls)`. From a host terminal:

```sh
curl --cacert .demo/tls/cert.pem https://localhost:18443/hello
```
