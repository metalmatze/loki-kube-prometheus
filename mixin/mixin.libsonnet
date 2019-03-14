local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';

{
  _config+:: {
    namespace: 'default',

    loki+: {
      name: 'loki',
      image: 'grafana/loki:master',
      labels: { app: 'loki' },

      config+: {
        auth_enabled: false,
        server: {
          http_listen_port: 3100,
          log_level: 'debug',
        },
        limits_config: {
          enforce_metric_name: false,
        },
        ingester: {
          lifecycler: {
            ring: {
              store: 'inmemory',
              replication_factor: 1,
            },
          },
          chunk_idle_period: '15m',
        },
        schema_config: {
          configs: [
            {
              from: 0,
              store: 'boltdb',
              object_store: 'filesystem',
              schema: 'v9',
              index: {
                prefix: 'index_',
                period: '168h',
              },
            },
          ],
        },
        storage_config: {
          boltdb: {
            directory: '/data/loki/index',
          },
          filesystem: {
            directory: '/data/loki/chunks',
          },
        },
      },
    },

    promtail+: {
      name: 'promtail',
      image: 'grafana/promtail:master',
      labels: { app: 'promtail' },

      config+: {
        server: {
          log_level: 'debug',
        },
        scrape_configs: [
          {
            job_name: 'kubernetes-pods',
            kubernetes_sd_configs: [
              {
                role: 'pod',
              },
            ],
            relabel_configs: [
              {
                source_labels: [
                  '__meta_kubernetes_pod_node_name',
                ],
                target_label: '__host__',
              },
              {
                action: 'drop',
                regex: '^$',
                source_labels: [
                  '__meta_kubernetes_pod_label_name',
                ],
              },
              {
                action: 'replace',
                replacement: '$1',
                separator: '/',
                source_labels: [
                  '__meta_kubernetes_namespace',
                  '__meta_kubernetes_pod_label_name',
                ],
                target_label: 'job',
              },
              {
                action: 'replace',
                source_labels: [
                  '__meta_kubernetes_namespace',
                ],
                target_label: 'namespace',
              },
              {
                action: 'replace',
                source_labels: [
                  '__meta_kubernetes_pod_name',
                ],
                target_label: 'instance',
              },
              {
                action: 'replace',
                source_labels: [
                  '__meta_kubernetes_pod_container_name',
                ],
                target_label: 'container_name',
              },
              {
                action: 'labelmap',
                regex: '__meta_kubernetes_pod_label_(.+)',
              },
              {
                replacement: '/var/log/pods/$1/*.log',
                separator: '/',
                source_labels: [
                  '__meta_kubernetes_pod_uid',
                  '__meta_kubernetes_pod_container_name',
                ],
                target_label: '__path__',
              },
            ],
          },
          {
            job_name: 'kubernetes-pods-app',
            kubernetes_sd_configs: [
              {
                role: 'pod',
              },
            ],
            relabel_configs: [
              {
                source_labels: [
                  '__meta_kubernetes_pod_node_name',
                ],
                target_label: '__host__',
              },
              {
                action: 'drop',
                regex: '^$',
                source_labels: [
                  '__meta_kubernetes_pod_label_app',
                ],
              },
              {
                action: 'replace',
                replacement: '$1',
                separator: '/',
                source_labels: [
                  '__meta_kubernetes_namespace',
                  '__meta_kubernetes_pod_label_app',
                ],
                target_label: 'job',
              },
              {
                action: 'replace',
                source_labels: [
                  '__meta_kubernetes_namespace',
                ],
                target_label: 'namespace',
              },
              {
                action: 'replace',
                source_labels: [
                  '__meta_kubernetes_pod_name',
                ],
                target_label: 'instance',
              },
              {
                action: 'replace',
                source_labels: [
                  '__meta_kubernetes_pod_container_name',
                ],
                target_label: 'container_name',
              },
              {
                action: 'labelmap',
                regex: '__meta_kubernetes_pod_label_(.+)',
              },
              {
                replacement: '/var/log/pods/$1/*.log',
                separator: '/',
                source_labels: [
                  '__meta_kubernetes_pod_uid',
                  '__meta_kubernetes_pod_container_name',
                ],
                target_label: '__path__',
              },
            ],
          },
        ],
      },
    },
  },

  serviceAccount:
    local serviceAccount = k.core.v1.serviceAccount;

    serviceAccount.new($._config.loki.name) +
    serviceAccount.mixin.metadata.withNamespace($._config.namespace),

  promtail+:: {
    configmap:
      local configmap = k.core.v1.configMap;

      configmap.new($._config.promtail.name, {
        'promtail.yaml': std.manifestYamlDoc($._config.promtail.config),
      }) +
      configmap.mixin.metadata.withNamespace($._config.namespace),

    daemonset:
      local daemonset = k.apps.v1beta2.daemonSet;
      local container = daemonset.mixin.spec.template.spec.containersType;
      local volume = daemonset.mixin.spec.template.spec.volumesType;
      local containerPort = container.portsType;
      local containerVolumeMount = container.volumeMountsType;
      local podSelector = daemonset.mixin.spec.template.spec.selectorType;
      local toleration = daemonset.mixin.spec.template.spec.tolerationsType;
      local containerEnv = container.envType;

      local c =
        container.new($._config.promtail.name, $._config.promtail.image) +
        container.withArgs([
          '-config.file=/etc/promtail/promtail.yaml',
          '-client.url=http://' + $._config.loki.name + '.' + $._config.namespace + '.svc.cluster.local:3100/api/prom/push',
        ]) +
        container.withEnv([
          container.envType.fromFieldPath('HOSTNAME', 'spec.nodeName'),
        ]) +

        container.withVolumeMounts([
          containerVolumeMount.new('config', '/etc/promtail'),
          containerVolumeMount.new('varlog', '/var/log'),
          containerVolumeMount.new('varlibdockercontainers', '/var/lib/docker/containers'),
        ]);
      // container.mixin.resources.withRequests({ cpu: '102m', memory: '180Mi' }) +
      // container.mixin.resources.withLimits({ cpu: '250m', memory: '180Mi' });

      local volumes = [
        { name: 'config', configMap: { name: $.promtail.configmap.metadata.name } },
        volume.fromHostPath('varlog', '/var/log'),
        volume.fromHostPath('varlibdockercontainers', '/var/lib/docker/containers'),
      ];

      daemonset.new() +
      daemonset.mixin.metadata.withLabels($._config.promtail.labels) +
      daemonset.mixin.metadata.withName($._config.promtail.name) +
      daemonset.mixin.metadata.withNamespace($._config.namespace) +
      daemonset.mixin.spec.selector.withMatchLabels($._config.promtail.labels) +
      daemonset.mixin.spec.template.metadata.withLabels($._config.promtail.labels) +
      daemonset.mixin.spec.template.spec.withContainers(c) +
      daemonset.mixin.spec.template.spec.withHostPid(true) +
      daemonset.mixin.spec.template.spec.withNodeSelector({ 'beta.kubernetes.io/os': 'linux' }) +
      daemonset.mixin.spec.template.spec.withServiceAccountName($.serviceAccount.metadata.name) +
      // daemonset.mixin.spec.template.spec.withTolerations([masterToleration]) +
      daemonset.mixin.spec.template.spec.withVolumes(volumes),

    podSecurityPolicy:
      local psp = k.extensions.v1beta1.podSecurityPolicy;

      psp.new() +
      psp.mixin.metadata.withName($._config.promtail.name) +
      psp.mixin.metadata.withNamespace($._config.namespace) +
      psp.mixin.spec.withPrivileged(true) +
      psp.mixin.spec.withAllowPrivilegeEscalation(true) +
      psp.mixin.spec.withVolumes(['secret', 'configMap', 'hostPath']) +
      psp.mixin.spec.withHostNetwork(true) +
      psp.mixin.spec.withHostIpc(true) +
      psp.mixin.spec.withHostPid(true) +
      psp.mixin.spec.withReadOnlyRootFilesystem(false) +
      psp.mixin.spec.runAsUser.withRule('RunAsAny') +
      psp.mixin.spec.seLinux.withRule('RunAsAny') +
      psp.mixin.spec.supplementalGroups.withRule('RunAsAny') +
      psp.mixin.spec.fsGroup.withRule('RunAsAny'),

    role:
      local role = k.rbac.v1.role;
      local rules = role.rulesType;

      role.new() +
      role.mixin.metadata.withName($._config.promtail.name) +
      role.mixin.metadata.withNamespace($._config.namespace) +
      role.withRules([
        rules.new() +
        rules.withApiGroups(['extensions']) +
        rules.withResources(['podsecuritypolicies']) +
        rules.withVerbs(['use']) +
        rules.withResourceNames([$._config.promtail.name]),
      ]),

    roleBinding:
      local roleBinding = k.rbac.v1.roleBinding;

      roleBinding.new() +
      roleBinding.mixin.metadata.withName($._config.promtail.name) +
      roleBinding.mixin.metadata.withNamespace($._config.namespace) +
      roleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
      roleBinding.mixin.roleRef.withName($._config.promtail.name) +
      roleBinding.mixin.roleRef.mixinInstance({ kind: 'Role' }) +
      roleBinding.withSubjects([{ kind: 'ServiceAccount', name: $.serviceAccount.metadata.name }]),

    clusterRole:
      local clusterRole = k.rbac.v1.clusterRole;
      local rulesType = clusterRole.rulesType;

      clusterRole.new() +
      clusterRole.mixin.metadata.withName($._config.promtail.name) +
      clusterRole.withRules([
        rulesType.new() +
        rulesType.withApiGroups(['']) +
        rulesType.withResources(['nodes', 'nodes/proxy', 'services', 'endpoints', 'pods']) +
        rulesType.withVerbs(['list', 'get', 'watch']),
      ]),

    clusterRoleBinding:
      local clusterRoleBinding = k.rbac.v1.clusterRoleBinding;

      clusterRoleBinding.new() +
      clusterRoleBinding.mixin.metadata.withName($._config.promtail.name) +
      clusterRoleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
      clusterRoleBinding.mixin.roleRef.withName($.promtail.clusterRoleBinding.metadata.name) +
      clusterRoleBinding.mixin.roleRef.mixinInstance({ kind: 'ClusterRole' }) +
      clusterRoleBinding.withSubjects([{
        kind: 'ServiceAccount',
        name: $.serviceAccount.metadata.name,
        namespace: $._config.namespace,
      }]),
  },

  loki+:: {
    configmap:
      local configmap = k.core.v1.configMap;

      configmap.new($._config.loki.name, {
        'loki.yaml': std.manifestYamlDoc($._config.loki.config),
      }) +
      configmap.mixin.metadata.withNamespace($._config.namespace),

    podSecurityPolicy:
      local psp = k.extensions.v1beta1.podSecurityPolicy;

      psp.new() +
      psp.mixin.metadata.withName($._config.loki.name) +
      psp.mixin.metadata.withNamespace($._config.namespace) +
      psp.mixin.spec.withPrivileged(false) +
      psp.mixin.spec.withAllowPrivilegeEscalation(false) +
      psp.mixin.spec.withVolumes(['configMap', 'emptyDir', 'persistentVolumeClaim']) +
      psp.mixin.spec.withHostNetwork(false) +
      psp.mixin.spec.withHostIpc(false) +
      psp.mixin.spec.withHostPid(false) +
      psp.mixin.spec.withReadOnlyRootFilesystem(false) +
      psp.mixin.spec.runAsUser.withRule('RunAsAny') +
      psp.mixin.spec.seLinux.withRule('RunAsAny') +
      psp.mixin.spec.supplementalGroups.withRule('RunAsAny') +
      psp.mixin.spec.fsGroup.withRule('RunAsAny'),

    role:
      local role = k.rbac.v1.role;
      local rules = role.rulesType;

      role.new() +
      role.mixin.metadata.withName($._config.loki.name) +
      role.mixin.metadata.withNamespace($._config.namespace) +
      role.withRules([
        rules.new() +
        rules.withApiGroups(['extensions']) +
        rules.withResources(['podsecuritypolicies']) +
        rules.withVerbs(['use']) +
        rules.withResourceNames([$._config.loki.name]),
      ]),

    roleBinding:
      local roleBinding = k.rbac.v1.roleBinding;

      roleBinding.new() +
      roleBinding.mixin.metadata.withName($._config.loki.name) +
      roleBinding.mixin.metadata.withNamespace($._config.namespace) +
      roleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
      roleBinding.mixin.roleRef.withName($._config.loki.name) +
      roleBinding.mixin.roleRef.mixinInstance({ kind: 'Role' }) +
      roleBinding.withSubjects([{ kind: 'ServiceAccount', name: $.serviceAccount.metadata.name }]),

    service:
      local service = k.core.v1.service;
      local servicePort = service.mixin.spec.portsType;

      service.new(
        $._config.loki.name,
        $._config.loki.labels,
        servicePort.newNamed('loki', 3100, 'loki'),
      ) +
      service.mixin.metadata.withNamespace($._config.namespace) +
      service.mixin.metadata.withLabels({ app: $._config.loki.name }),

    deployment:
      local deployment = k.apps.v1beta2.deployment;
      local volume = deployment.mixin.spec.template.spec.volumesType;
      local container = deployment.mixin.spec.template.spec.containersType;
      local containerVolumeMount = container.volumeMountsType;

      local c =
        container.new($._config.loki.name, $._config.loki.image) +
        container.withImagePullPolicy('Always') +
        container.withArgs([
          '-config.file=/etc/loki/loki.yaml',
        ]) +
        container.withPorts([{ containerPort: 3100, name: 'loki' }]) +
        container.withVolumeMounts([
          containerVolumeMount.new('config', '/etc/loki'),
        ],);

      deployment.new($._config.loki.name, 1, c, $._config.loki.labels) +
      deployment.mixin.metadata.withNamespace($._config.namespace) +
      deployment.mixin.metadata.withLabels($._config.loki.labels) +
      deployment.mixin.spec.selector.withMatchLabels($._config.loki.labels) +
      deployment.mixin.spec.template.spec.withServiceAccountName($.serviceAccount.metadata.name) +
      deployment.mixin.spec.template.spec.withNodeSelector({ 'beta.kubernetes.io/os': 'linux' }) +
      deployment.mixin.spec.strategy.rollingUpdate.withMaxSurge(1) +
      deployment.mixin.spec.strategy.rollingUpdate.withMaxUnavailable(0) +
      deployment.mixin.spec.template.spec.withVolumes([
        { name: 'config', configMap: { name: $.loki.configmap.metadata.name } },
      ]),
  },
}
