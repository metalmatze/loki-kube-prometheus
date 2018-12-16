local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';

(import 'promtail/promtail.libsonnet') +
(import 'loki/loki.libsonnet') +
(import 'config.libsonnet') +
{
  promtail_config_map+: {
    metadata+: {
      namespace: $._config.namespace,
    },
  },

  promtail_daemonset+: {
    metadata+: {
      namespace: $._config.namespace,
    },
  },

  local o = super.promtail_rbac,
  promtail_rbac+: {
    [k]: o[k] {
      metadata+: {
        namespace: $._config.namespace,
      },
    }
    for k in std.objectFields(o)
  },

  config_file+: {
    metadata+: {
      namespace: $._config.namespace,
    },
  },

  distributor_service+: {
    metadata+: {
      namespace: $._config.namespace,
    },
  },
  distributor_deployment+: {
    metadata+: {
      namespace: $._config.namespace,
    },
  },

  ingester_service+: {
    metadata+: {
      namespace: $._config.namespace,
    },
  },
  ingester_deployment+: {
    metadata+: {
      namespace: $._config.namespace,
    },
  },

  querier_service+: {
    metadata+: {
      namespace: $._config.namespace,
    },
  },
  querier_deployment+: {
    metadata+: {
      namespace: $._config.namespace,
    },
  },

  table_manager_service+: {
    metadata+: {
      namespace: $._config.namespace,
    },
  },
  table_manager_deployment+: {
    metadata+: {
      namespace: $._config.namespace,
    },
  },
}
