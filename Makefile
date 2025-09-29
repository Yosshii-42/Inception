COMPOSE = docker compose -p srcs -f srcs/docker-compose.yml
NAME 	= srcs

DATA_DIR := /home/yotsurud/data
DB_DIR	 := $(DATA_DIR)/db
WP_DIR	 := $(DATA_DIR)/wp
SUDO	 ?= sudo

all: up

hosts:
	@sh tools/hosts.sh

up: hosts
	$(COMPOSE) up -d --build
	$(COMPOSE) ps

unhosts:
	@sudo sed -E -i.bak \
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
	- sudo rm -rf $(DB_DIR)/* $(WP_DIR)/* || true

re: fclean up

.PHONY: all hosts up unhosts down build logs ps clean fclean re
