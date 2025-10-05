FROM debian:12

RUN apt-get update && apt-get install -y --no-install-recommends \
	nginx openssl ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

# setting & init
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

EXPOSE 443
ENTRYPOINT ["/usr/local/bin/init.sh"]

# nginxのログをDockerのdocker logsに流すためのセットアップ
RUN mkdir -p /var/log/nginx \
	&& rm  -f /var/log/nginx/access.log /var/log/nginx/error.log \
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log
