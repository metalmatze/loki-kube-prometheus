all: jb manifests

.PHONY: jb
jb:
	go get -v -u github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
	cd mixin && jb install; cd ..

list/loki.yaml: example.jsonnet mixin/mixin.libsonnet mixin/vendor/
	jsonnet fmt -i mixin/mixin.libsonnet
	jsonnet fmt -i example.jsonnet
	jsonnet -J mixin/vendor -J mixin/vendor/ksonnet/ksonnet.beta.3/ example.jsonnet | gojsontoyaml > list/loki.yaml
