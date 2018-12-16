# Loki with kube-prometheus

This is an experimental try to incoporate [Loki](https://github.com/grafana/loki)
into my current stack that runs with [kube-prometheus](https://github.com/coreos/prometheus-operator/tree/master/contrib/kube-prometheus).

As kube-prometheus uses the [Prometheus Operator](https://github.com/coreos/prometheus-operator)
this repository will add things like [ServiceMonitors and PrometheusRule](https://github.com/coreos/prometheus-operator#customresourcedefinitions).

## Jsonnet

This stack is based on [jsonnet](http://jsonnet.org) and simply extends what Loki already provides.

## Manifests & List

We have provide pre-rendered YAML.

One is a complete [list](list/loki.yaml) of everything that needs to be installed.
You can simply `kubectl apply -f list/loki.yaml` to deploy all components to the `loki` namespace.

The other option is a folder called [manifests/](manifests/). This contains all components as separate files.
By default everything will also be installed into the `loki` namespace with `kubectl apply -f manifests/`.
The folder has the advantage that things can be more fine grained applied and removed.

## Current problems with generating

The reference to the consul mixin is broken.  
Fix it by running `mv mixin/vendor/consul/mixin.libsonnet mixin/vendor/consul/consul.libsonnet`.

The kausal.libsonnet is broken when converting and object to string.
Fix it by changing the following in `mixin/vendor/ksonnet-util/kausal.libsonnet`

```diff
    manifestYaml(value):: (
-     local f = std.native('manifestYamlFromJson');
-     f(std.toString(value))
+     std.manifestYamlDoc(value)
    ),
```
