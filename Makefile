.PHONY: serve test clean instantiate

JULIA_CMD = julia --color=yes --startup-file=no

serve: instantiate
	bin/serve

test: instantiate
	bin/runtests.jl

clean:
	rm -rf src/__site

instantiate:
	$(JULIA_CMD) -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'
