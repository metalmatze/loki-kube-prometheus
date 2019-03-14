local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';

local mixin = (import 'mixin.libsonnet') + {
  _config+:: {
    namespace: 'logging',
  },
};

k.core.v1.list.new([
  mixin.serviceAccount,

  mixin.promtail.configmap,
  mixin.promtail.daemonset,
  mixin.promtail.podSecurityPolicy,
  mixin.promtail.role,
  mixin.promtail.roleBinding,
  mixin.promtail.clusterRole,
  mixin.promtail.clusterRoleBinding,

  mixin.loki.configmap,
  mixin.loki.podSecurityPolicy,
  mixin.loki.role,
  mixin.loki.roleBinding,
  mixin.loki.service,
  mixin.loki.deployment,
])
