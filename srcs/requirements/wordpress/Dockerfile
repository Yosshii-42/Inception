FROM debian:bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
	php-fpm php-mysql php-cli php-curl php-zip php-xml php-mbstring curl ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

# wp-cliを配置
RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
		-o /usr/local/bin/wp \
	&& chmod +x /usr/local/bin/wp

# PHP-FPMを9000でlisten / 環境変数を渡せるように
RUN for f in /etc/php/*/fpm/pool.d/www.conf; do \
	[ -f "$f" ] && sed -ri 's|^;?listen *=.*$|listen = 9000|' "$f" \
		    && sed -ri 's|^;?clear_env *=.*$|clear_env = no|' "$f"; \
	done

WORKDIR /var/www/html
RUN mkdir -p /var/www/html && chown -R www-data:www-data /var/www/html

# 起動スクリプト
COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

EXPOSE 9000
VOLUME ["/var/www/html"]

# init.shが最終的にphp-fpmをexecする前提
ENTRYPOINT ["/usr/local/bin/init.sh"]
CMD ["php-fpm", "-F"]

ENV WP_CLI_ALLOW_ROOT=1
