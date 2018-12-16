{
  _config+:: {
    namespace: 'loki',

    htpasswd_contents: 'loki:$apr1$H4yGiGNg$ssl5/NymaGFRUvxIV1Nyr.',
    promtail_config: {
      scheme: 'http',
      hostname: 'gateway.%(namespace)s.svc' % $._config,
      username: 'loki',
      password: 'password'
    },
    replication_factor: 3,
    consul_replicas: 1,
    storage_backend: 'aws',

    bigtable_instance: 'bigtable',
    bigtable_project: 'bigtable',
  },
}
