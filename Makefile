all: jb manifests

.PHONY: jb
jb:
	go get -v -u github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
	cd mixin && jb install; cd ..

list/loki.yaml: mixin/list.jsonnet mixin/loki.libsonnet mixin/vendor/
	jsonnet fmt -i mixin/loki.libsonnet
	jsonnet fmt -i mixin/list.jsonnet
	jsonnet -J mixin/vendor -J mixin/vendor/ksonnet/ksonnet.beta.3/ mixin/list.jsonnet | gojsontoyaml > list/loki.yaml

manifests:
	jsonnet fmt -i mixin/loki.libsonnet
	jsonnet -J mixin/vendor -J mixin/vendor/ksonnet/ksonnet.beta.3/ -m manifests mixin/loki.libsonnet | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml; rm -f {}' -- {}
