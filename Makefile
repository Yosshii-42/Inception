COMPOSE = docker compose -p srcs -f srcs/docker-compose.yml

DATA_DIR := /home/yotsurud/data
DB_DIR	 := $(DATA_DIR)/db
WP_DIR	 := $(DATA_DIR)/wp
SUDO	 ?= sudo

all: up

hosts:
	@$(SUDO) sh tools/hosts.sh

preflight: hosts
	# コマンドを同じシェルで実行し1つでも失敗したら即終了
	@set -e; \ 
	$(SUDO) mkdir -p "$(DB_DIR)" "$(WP_DIR)"; \
	$(SUDO) chmod 755 "$(DATA_DIR)" "$(DB_DIR)" "$(WP_DIR)"; \
	# 以後で参照する設定ファイルのシェル変数を定義
	CONF=/etc/docker/daemon.json; \
	# daemon.json が無い or "dns" キーが未設定ならファイルを新規作成 or 上書き
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
