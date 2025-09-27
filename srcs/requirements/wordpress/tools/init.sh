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
		export "$var=$val"
	fi
}
read_secret WP_ADMIN_PASSWORD
read_secret WP_USER2_PASSWORD
read_secret WORDPRESS_DB_PASSWORD

# 公開URLの組み立て
scheme="${PUBLIC_SCHEME:-https}"
host="${PUBLIC_HOST:-yotsurud.42.fr}"
port="${PUBLIC_PORT:-}"
if [ -n "$port" ]; then
	PUBLIC_URL="${scheme}://${host}:${port}"
else
	PUBLIC_URL="${scheme}://${host}"
fi

# wpコア
mkdir -p /home/yotsurud/data
chown -R www-data:www-data /home/yotsurud/data
cd /home/yotsurud/data

# コアがなければ取得
if [ ! -f wp-settings.php ]; then
	i=0
	until wp core download --allow-root >/dev/null 2>&1; do
		i=$((i+1))
		[ $i -ge 5 ] && echo "[wp] core download failed (retried $i)" >&2 && break
		sleep 2
	done
fi

# DBが応答するまで待つ
echo "[wp] waiting for database..."
ok=0
for i in $(seq 1 60); do
	if  php -r '
		[$h,$p]=array_pad(explode(":",getenv("WORDPRESS_DB_HOST"),2),2,3306);
		$c=@mysqli_connect($h,getenv("WORDPRESS_DB_USER"),getenv("WORDPRESS_DB_PASSWORD"),getenv("WORDPRESS_DB_NAME"),(int)$p);
		exit($c ? 0 : 1);
	'; then
		echo "[wp] DB OK"
		ok=1
		break
	fi
	sleep 2
done
[ "$ok" -eq 1 ] || { echo "[wp] DB not ready (timeout)" >&2; exit 1;}

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

# 初回インストール時に --urlを指定
if ! wp core is-installed --allow-root >/dev/null 2>&1; then
	wp core install \
		--url="$PUBLIC_URL" \
		--title="Inception" \
		--admin_user="user1" \
		--admin_password="${WP_ADMIN_PASSWORD}" \
		--admin_email="admin@example.com" \
		--skip-email \
		--allow-root
else
	wp option update home		"$PUBLIC_URL" --allow-root
	wp option update siteurl	"$PUBLIC_URL" --allow-root
fi

# 追加ユーザ
if [ -n "${WP_USER2_LOGIN:-}" ] && ! wp user get "${WP_USER2_LOGIN}" --field=ID --allow-root >/dev/null 2>&1; then
	: "${WP_USER2_EMAIL:?WP_USER2_EMAIL is required when WP_USER2_LOGIN is set}"
	: "${WP_USER2_PASSWORD:?WP_USER2_PASSWORD or *_FILE is required when WP_USER2_LOGIN is set}"
	wp user create "${WP_USER2_LOGIN}" "${WP_USER2_EMAIL}" \
		--role="${WP_USER2_ROLE:-subscriber}" \
		--user_pass="${WP_USER2_PASSWORD}" \
		--allow-root
fi

# 最終権限整備
chown -R www-data:www-data /home/yotsurud/data

# PHP-FPM
mkdir -p /run/php
chown root:root /run/php
chmod 755 /run/php

# CMDにバトンタッチ (php-fpm の自動検出)
PHP_FPM_BIN="$(command -v php-fpm 2>/dev/null || true)"
[ -x "${PHP_FPM_BIN:-}" ] || PHP_FPM_BIN="$(command -v php-fpm8.2 2>/dev/null || true)"
[ -x "${PHP_FPM_BIN:-}" ] || PHP_FPM_BIN="$(command -v php8.2-fpm 2>/dev/null || true)"

if [ -z "${PHP_FPM_BIN:-}" ]; then
  echo "[FATAL] php-fpm not found" >&2
  exit 1
fi

exec "$PHP_FPM_BIN" -F
#if [ -x /usr/sbin/php-fpm7.4 ]; then
#	exec /usr/sbin/php-fpm7.4 -F
#elif command -v php-fpm >/dev/null 2>&1; then
#	exec php-fpm -F
#else
#	echo "[FATAL] php-fpm not found" >&2; exit 1
#fi
