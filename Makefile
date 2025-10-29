DOCKER_COMPOSE := docker compose
DOCKER_COMPOSE_YML := --file docker-compose.yml
ifneq ("$(wildcard docker-compose.local.yml)","")
DOCKER_COMPOSE_YML += --file docker-compose.local.yml
endif

language := node
FRONTEND_PORT ?= 3003
SUCCESS_MESSAGE := "✅ $(language) quickstart is running on http://localhost:$(FRONTEND_PORT)"

.PHONY: up
up:
	REACT_APP_API_HOST=http://$(language):${APP_PORT} \
	$(DOCKER_COMPOSE) \
		$(DOCKER_COMPOSE_YML) \
		$@ --build --detach --remove-orphans \
		$(language)
	@echo $(SUCCESS_MESSAGE)

.PHONY: logs
logs:
	$(DOCKER_COMPOSE) \
		$@ --follow \
		$(language) frontend

.PHONY: stop build
stop build:
	$(DOCKER_COMPOSE) \
		$(DOCKER_COMPOSE_YML) \
		$@ \
		$(language) frontend

