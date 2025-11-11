# TODO I think consul-connect needs this,
# test if that's still true without the sidecar envoy thing
service_prefix "" { policy = "read" }
node_prefix    "" { policy = "read" }
