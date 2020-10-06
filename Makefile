.PHONY: serve clean instantiate

JULIA_CMD = julia --color=yes --startup-file=no

serve:
	$(MAKE) instantiate
	bin/serve

clean:
	rm -rf src/__site

instantiate:
	$(JULIA_CMD) -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'
