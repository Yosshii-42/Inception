#!/bin/sh
set -eu

ENTRY="127.0.0.1 yotsurud.42.fr"

# 既存値チェック
if grep -qxF "$ENTRY" /etc/hosts; then
	echo "[hosts] already set"
	exit 0
fi

# 同ドメインの古い行があったら削除して追記
# sed -i.bakはインプレース編集＋バックアップ作成
if grep -qE '(^|[[:space:]])yotsurud\.42\.fr([[:space:]]|$)' /etc/hosts; then
	echo "[hosts] update existing entry"
	sudo sed -E -i.bak '
		/^[[:space:]]*#/!{
			/(^|[[:space:]])yotsurud\.42\.fr([[:space:]]|$)/d
		}
	' /etc/hosts
fi

printf '%s\n' "$ENTRY" | sudo tee -a /etc/hosts >/dev/null
echo "[hosts] added: $ENTRY"
