WORKSPACE := $(shell pwd)
MIN_COVERAGE := 30

check_defined = \
				$(strip $(foreach 1,$1, \
				$(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
				  $(if $(value $1),, \
				  $(error Undefined $1$(if $2, ($2))$(if $(value @), \
				  required by target `$@`)))

.PHONY: format
format:
	black handler.py src/commercetools_token_refresher tests
	terraform fmt terraform

.PHONY: mypy
mypy:
	 mypy --config-file=mypy.ini src/commercetools_token_refresher

.PHONY: test
test:
	py.test tests/

.PHONY: install
install:
	python3 -m pip install -e .[test]

.PHONY: coverage
coverage:
	py.test tests/ --cov=commercetools_token_refresher --cov-report=xml --cov-report=term-missing --junit-xml=reports/junit.xml --cov-fail-under=$(MIN_COVERAGE)

.PHONY: flake8
flake8:
	flake8 src tests

.PHONY: build
build: clean
	./build.sh package

.PHONY: clean
clean:
	rm -rf $(WORKSPACE)/build/*
	rm -rf $(WORKSPACE)/dist/
	mkdir $(WORKSPACE)/dist/
	./build.sh clean

.PHONY: requirements
requirements:
	pip install pip-tools
	pip-compile requirements.in --no-emit-trusted-host --no-index --no-header

