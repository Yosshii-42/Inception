#!/bin/bash

# エラー発生時に終了させる
set -euo pipefail

DATADIR="/var/lib/mysql"

# ソケット用ディレクトリ
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

# *_FILE を読んで環境変数に展開（Docker secret対応）
for v in MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD MYSQL_ROOT_PASSWORD; do
	file_var="${v}_FILE"
	if [[ -n "${!file_var:-}" && -r "${!file_var}" ]]; then
		export "$v"="$(<"${!file_var}")"
	fi
done

# 必須変数チェック
: "${MYSQL_DATABASE:?required}"
: "${MYSQL_USER:?required}"
: "${MYSQL_PASSWORD:?required}"
: "${MYSQL_ROOT_PASSWORD:?required}"

if [[ ! -d "${DATADIR}/mysql" ]]; then
	echo "[init] Initializing datadir..." >&2
	install -o mysql -g mysql -m 0755 -d "${DATADIR}"
	mariadb-install-db --user=mysql --datadir="${DATADIR}" \
		--auth-root-authentication-method=normal >/dev/null
	
	echo "[init] Generating /tmp/init.sql..." >&2
	cat > /tmp/init.sql <<EOF

-- set root password
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

-- create app db & user
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
ALTER USER                 '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'wordpress.srcs_inception' IDENTIFIED BY '${MYSQL_PASSWORD}';
ALTER USER                 '${MYSQL_USER}'@'wordpress.srcs_inception' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'wordpress.srcs_inception';
FLUSH PRIVILEGES;
EOF

	# 初回のみinit-fileで起動してSQLを適用
	exec mysqld --user=mysql --datadir="${DATADIR}" --bind-address=0.0.0.0 \
		--init-file=/tmp/init.sql
fi

echo "[run] Datadir present. Starting mysqld normally..." >&2
exec mysqld --user=mysql --datadir="$DATADIR" --bind-address=0.0.0.0
