all: jb manifests

.PHONY: jb
jb:
	go get -v -u github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
	cd mixin && jb install; cd ..

list/loki.yaml: example.jsonnet mixin/mixin.libsonnet mixin/vendor/
	jsonnet fmt -i mixin/mixin.libsonnet

manifests:
	jsonnet fmt -i mixin/loki.libsonnet
	jsonnet -J mixin/vendor -J mixin/vendor/ksonnet/ksonnet.beta.3/ -m manifests mixin/loki.libsonnet | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml; rm -f {}' -- {}
