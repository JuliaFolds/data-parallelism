include: config.mk

.PHONY: serve test clean instantiate

JULIA ?= julia
JULIA_CMD ?= $(JULIA) --color=yes --startup-file=no

serve: instantiate
	bin/serve

test: instantiate
	bin/runtests.jl

clean:
	rm -rf src/__site

instantiate:
	$(JULIA_CMD) -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'

config.mk:
	ln -s default-config.mk $@
