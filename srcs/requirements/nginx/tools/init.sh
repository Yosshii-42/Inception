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

# フォアグラウンドで起動 PID1をnginxに置き換え
exec nginx -g 'daemon off;'

# -x509: その場で自己署名のサーバ証明書を作る
# -nodes: 秘密鍵にパスフレーズをかけない
# -newkey rsa:2048: 2048bit の新規鍵
# -days 365: 有効期限1年
# -subj "/CN=$DOMAIN": Common Name をドメインに
# -addext "subjectAltName=…": SAN（$DOMAINとwww.$DOMAIN）を付与

# exec nginx -g 'daemon off;'
#  コンテナは PID 1 のプロセスが生きている間だけ動く
#  デーモン化する：バックグラウンド常駐（Dockerでは不向き）
#  デーモン化しない：フォアグラウンドで動作（Dockerでは推奨）