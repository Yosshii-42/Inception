FROM debian:bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
	mariadb-server mariadb-client ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

# 必要なディレクトリ作成＆権限
RUN mkdir -p /var/run/mysqld /docker-entrypoint-initdb.d \
	&& chown -R mysql:mysql /var/run/mysqld /var/lib/mysql /docker-entrypoint-initdb.d

# server setting
COPY ./conf/my.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# init script
COPY ./tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

# (rootのまま)　起動時はinit.shを必ず通す　最後にmysqlを実行
EXPOSE 3306
VOLUME ["/var/lib/mysql"]
ENTRYPOINT ["/usr/local/bin/init.sh"]
CMD ["mysqld","--user=mysql","--datadir=/var/lib/mysql","--bind-address=0.0.0.0"]
