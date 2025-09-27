COMPOSE = docker compose -p srcs -f srcs/docker-compose.yml
NAME 	= srcs

all: up

hosts:
	@sh tools/hosts.sh

prepare:
	sudo mkdir -p /home/yotsurud/data/mariadb /home/yotsurud/data/wordpress
	sudo chown -R 999:999 	/home/yotsurud/data/mariadb
	sudo chmod -R 700	/home/yotsurud/data/mariadb
	sudo chown -R 33:33	/home/yotsurud/data/wordpress
	sudo find /home/yotsurud/data/wordpress -type d -exec chmod 755 {} +
	sudo find /home/yotsurud/data/wordpress -type f -exec chmod 644 {} +

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

re: fclean up

.PHONY: all hosts up unhosts down build logs ps clean fclean re
