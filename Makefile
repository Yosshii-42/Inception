COMPOSE = docker compose -f srcs/docker-compose.yml
NAME 	= srcs

all: up

up:
	$(COMPOSE) up -d --build

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
	-docker image rm yotsuru/mariadb:1.0 yotsurud/wordpress:1.0 yotsurud/nginx:1.0 || true

re: fclean up

.PHONY: all up down build logs ps clean fclean re
