local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';
local loki = import 'loki.libsonnet';

k.core.v1.list.new(
  [
    loki.namespace,
    loki.promtail_config_map,
    loki.promtail_daemonset,
    loki.config_file,
    loki.distributor_service,
    loki.distributor_deployment,
    loki.ingester_service,
    loki.ingester_deployment,
    loki.querier_service,
    loki.querier_deployment,
    // loki.table_manager_service,
    // loki.table_manager_deployment,
  ] +
  [
    loki.promtail_rbac[o]
    for o in std.objectFields(loki.promtail_rbac)
  ],
)
