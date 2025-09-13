#!/bin/sh

set -eu

DOMAIN="${DOMAIN_NAME:-yotsurud.42.fr}"
SSL_DIR=/etc/nginx/ssl
CRT="$SSL_DIR/$DOMAIN.crt"
KEY="$SSL_DIR/$DOMAIN.key"

mkdir -p "$SSL_DIR"

# 証明書がなければSAN付きで作成
if [ ! -f "$CRT" ] || [ ! -f "$KEY" ]; then
	echo "[nginx] generating self-signed cert for $DOMAIN"
	openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
		-subj "/CN=$DOMAIN" \
		-keyout "$KEY" -out "$CRT" \
		-addext "subjectAltName=DNS:$DOMAIN,DNS:www.$DOMAIN"
fi

# 構文チェックに失敗したらエラー
nginx -t

# フォアグラウンドで起動
exec nginx -g 'daemon off;'
