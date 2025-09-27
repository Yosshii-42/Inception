FROM debian:12

RUN apt-get update && apt-get install -y --no-install-recommends \
	php-fpm php-mysql php-cli php-curl php-zip php-xml php-mbstring curl ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

# wp-cliを配置
RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
		-o /usr/local/bin/wp \
	&& chmod +x /usr/local/bin/wp

# PHP-FPMを0.0.0.0:9000でlisten / 環境変数を渡せるように
RUN for f in /etc/php/*/fpm/pool.d/www.conf; do \
	[ -f "$f" ] && sed -ri 's|^;?listen *=.*$|listen = 0.0.0.0:9000|' "$f" \
		    && sed -ri 's|^;?clear_env *=.*$|clear_env = no|' "$f"; \
	done
EXPOSE 9000

WORKDIR /home/yotsurud/data
RUN mkdir -p /home/yotsurud/data && chown -R www-data:www-data /home/yotsurud/data

# 起動スクリプト
COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

EXPOSE 9000
VOLUME ["/home/yotsurud/data"]

# init.shが最終的にphp-fpmをexecする前提
ENTRYPOINT ["/usr/local/bin/init.sh"]
CMD ["php-fpm", "-F"]

ENV WP_CLI_ALLOW_ROOT=1
