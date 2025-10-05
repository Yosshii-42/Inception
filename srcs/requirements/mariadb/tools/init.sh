#!/bin/bash
# 未定義や失敗で即落ちる
set -euo pipefail

DATADIR="/var/lib/mysql"

# ソケット用ディレクトリ
install -o mysql -g mysql -m 0755 -d /run/mysqld

# *_FILE を優先して環境変数に展開（空のときだけ読み込む）
for v in MARIADB_DATABASE MARIADB_USER MARIADB_PASSWORD MARIADB_ROOT_PASSWORD; do
  file_var="${v}_FILE"
  eval "cur=\${$v:-}"
  eval "path=\${$file_var:-}"
  if [[ -z "${cur}" && -n "${path:-}" && -r "${path}" ]]; then
    export "$v=$(tr -d $'\r\n' < "${path}")"
  fi
done

# 必須チェック 無ければ即エラー
: "${MARIADB_DATABASE:?required}"
: "${MARIADB_USER:?required}"
: "${MARIADB_PASSWORD:?required}"
: "${MARIADB_ROOT_PASSWORD:?required}"

# datadir 初期化（初回だけ）（サーバ起動は最後にまとめて行う）
install -o mysql -g mysql -m 0755 -d "${DATADIR}"
if [[ ! -d "${DATADIR}/mysql" ]]; then
  echo "[init] Initializing datadir..." >&2
  mariadb-install-db --user=mysql --datadir="${DATADIR}" \
    --auth-root-authentication-method=normal >/dev/null
fi

# 毎回流す ブートストラップ SQL を生成
cat > /tmp/bootstrap.sql <<'SQL'
-- root パスワード設定
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';

-- DB 作成（無ければ）
CREATE DATABASE IF NOT EXISTS `${MARIADB_DATABASE}`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- ユーザ作成/更新 冪等
CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
ALTER  USER               '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
GRANT ALL PRIVILEGES ON `${MARIADB_DATABASE}`.* TO '${MARIADB_USER}'@'%';

-- 権限付与
FLUSH PRIVILEGES;
SQL

# 変数展開したファイルを --init-file に渡す
envsubst < /tmp/bootstrap.sql > /tmp/bootstrap.expanded.sql

# 既存データの有無に関わらず 毎回 init-file を実行させて起動 PID1置き換え
exec mysqld --user=mysql --datadir="${DATADIR}" --bind-address=0.0.0.0 \
  --init-file=/tmp/bootstrap.expanded.sql

# MariaDB コンテナのエントリポイント
# 秘密情報を安全に読み込み
#  → データディレクトリを初期化（必要なら）
#  → 毎回の起動時にDB/ユーザ/権限を確実に整える、までを自動でやる