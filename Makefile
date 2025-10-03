COMPOSE = docker compose -p srcs -f srcs/docker-compose.yml

DATA_DIR := /home/yotsurud/data
DB_DIR	 := $(DATA_DIR)/db
WP_DIR	 := $(DATA_DIR)/wp
SUDO	 ?= sudo

all: up

hosts:
	@$(SUDO) sh tools/hosts.sh

preflight: hosts
	@set -e; \
	$(SUDO) mkdir -p "$(DB_DIR)" "$(WP_DIR)"; \
	$(SUDO) chmod 755 "$(DATA_DIR)" "$(DB_DIR)" "$(WP_DIR)"; \
	CONF=/etc/docker/daemon.json; \
	if ! grep -q '"dns"' "$$CONF" 2>/dev/null; then \
		echo '{ "dns": ["1.1.1.1", "8.8.8.8"] }' | $(SUDO) tee "$$CONF" >/dev/null; \
		$(SUDO) systemctl restart docker; \
	fi

up: preflight
	$(COMPOSE) up -d --build

unhosts:
	@$(SUDO) sed -E -i.bak \
		-e '/^[[:space:]]*#/b' \
		-e '/(^|[[:space:]])yotsurud\.42\.fr([[:space:]]|$$)/d' \
		/etc/hosts && echo "[hosts] removed"

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down --remove-orphans

fclean:
	$(COMPOSE) down -v --remove-orphans
	-docker image rm yotsurud/mariadb:1.0 yotsurud/wordpress:1.0 yotsurud/nginx:1.0 || true
	- $(SUDO) rm -rf $(DB_DIR)/* $(WP_DIR)/* || true

re: fclean up

.PHONY: all hosts preflight up unhosts down logs ps clean fclean re
