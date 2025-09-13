#!/bin/sh
set -eu

export WP_CLI_ALLOW_ROOT=1

# secrets 読み込み
read_secret() {
	var="$1"
	file_var="${var}_FILE"
	eval "cur=\${$var:-}"
	eval "path=\${$file_var:-}"
	if [ -z "${cur}" ] && [ -n "${path}" ] && [ -r "${path}" ]; then
		val="$(tr -d '\r\n' < "$path")"
		eval "export $var=\$val"
	fi
}
read_secret WP_ADMIN_PASSWORD
read_secret WP_USER2_PASSWORD
read_secret WORDPRESS_DB_PASSWORD

# PHP-FPM のpid置き場
mkdir -p /run/php && chmod 755 /run/php

# wpコア
mkdir -p /var/www/html
chown -R www-data:www-data /var/www/html
cd /var/www/html

# コアがなければ取得
if [ ! -f wp-settings.php ]; then
	i=0
	until wp core download --allow-root >/dev/null 2>&1; do
		i=$((i+1))
		[ $i -ge 5 ] && echo "[wp] core download failed (retried $i)" >&2 && break
		sleep 2
	done
fi

(
	# DBが応答するまで待つ
	echo "[wp] waiting for database..."
	for i in $(seq 1 60); do
		if  php -r '
			[$h,$p]=array_pad(explode(":",getenv("WORDPRESS_DB_HOST"),2),2,3306);
			$c=@mysqli_connect($h,getenv("WORDPRESS_DB_USER"),getenv("WORDPRESS_DB_PASSWORD"),getenv("WORDPRESS_DB_NAME"),(int)$p);
			exit($c ? 0 : 1);
		'; then
			echo "[wp] DB OK"
			break
		fi
		sleep 2
	done

	if [ $i -ge 60 ]; then
	       	echo "[wp] DB not ready (timeout)" >&2
		exit 0
	fi

	# wp-config.phpの用意（あるなら更新）
	if [ ! -f wp-config.php ]; then
		wp config create \
			--dbname="${WORDPRESS_DB_NAME}" \
			--dbuser="${WORDPRESS_DB_USER}" \
			--dbpass="${WORDPRESS_DB_PASSWORD}" \
			--dbhost="${WORDPRESS_DB_HOST}" \
			--dbprefix="${WORDPRESS_TABLE_PREFIX:-wp_}" \
			--skip-check --allow-root
	else
		# 既存の定数を現在の.envに合わせて更新
		wp config set DB_NAME     "${WORDPRESS_DB_NAME}"     --type=constant --allow-root
		wp config set DB_USER     "${WORDPRESS_DB_USER}"     --type=constant --allow-root
		wp config set DB_PASSWORD "${WORDPRESS_DB_PASSWORD}" --type=constant --allow-root
		wp config set DB_HOST     "${WORDPRESS_DB_HOST}"     --type=constant --allow-root
		if [ -n "${WORDPRESS_TABLE_PREFIX:-}" ]; then
			wp config set table_prefix "${WORDPRESS_TABLE_PREFIX}"    --type=variable --allow-root

		fi
	fi

	# 未インストールならインストール
	if ! wp core is-installed --allow-root; then
		: "${WP_ADMIN_PASSWORD:?WP_ADMIN_PASSWORD or WP_ADMIN_PASSWORD_FILE is required}"
		wp core install \
			--url="${WP_URL}" \
			--title="${WP_TITLE}" \
			--admin_user="${WP_ADMIN_USER}" \
			--admin_email="${WP_ADMIN_EMAIL}" \
			--skip-email --prompt=admin_password --allow-root <<EOF
${WP_ADMIN_PASSWORD}
EOF
	fi

	# set up second user
	if [ -n "${WP_USER2_LOGIN:-}" ] && ! wp user get "${WP_USER2_LOGIN}" --field=ID --allow-root >/dev/null 2>&1; then
		: "${WP_USER2_EMAIL:?WP_USER2_EMAIL is required when WP_USER2_LOGIN is set}"
		: "${WP_USER2_PASSWORD:?WP_USER2_PASSWORD or *_FILE is required when WP_USER2_LOGIN is set}"
		wp user create "${WP_USER2_LOGIN}" "${WP_USER2_EMAIL}" \
			--role="${WP_USER2_ROLE:-subscriber}" \
			--user_pass="${WP_USER2_PASSWORD}" \
			--allow-root
	fi
	chown -R www-data:www-data /var/www/html
)&

mkdir -p /run/php
chown root:root /run/php
chmod 755 /run/php

# CMDにバトンタッチ (php-fpm -F)
if [ -x /usr/sbin/php-fpm7.4 ]; then
	exec /usr/sbin/php-fpm7.4 -F
elif command -v php-fpm >/dev/null 2>&1; then
	exec php-fpm -F
else
	echo "[FATAL] php-fpm not found" >&2; exit 1
fi
