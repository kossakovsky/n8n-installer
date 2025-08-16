#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f ".env" ]]; then
  echo ".env не найден. Запустите из корня репозитория."
  exit 1
fi

read -r -p "Домен сайта (например, blog.example.com): " WP_DOMAIN
if [[ -z "${WP_DOMAIN}" ]]; then
  echo "Домен обязателен."
  exit 1
fi

WP_DB_PASS=$(openssl rand -base64 24 | tr -d '=+/')
WP_DB_ROOT_PASS=$(openssl rand -base64 24 | tr -d '=+/')

# Обновляем .env
sed -i "/^WORDPRESS_DOMAIN=/d" .env || true
sed -i "/^WORDPRESS_DB_PASSWORD=/d" .env || true
sed -i "/^WORDPRESS_DB_ROOT_PASSWORD=/d" .env || true
{
  echo "WORDPRESS_DOMAIN=${WP_DOMAIN}"
  echo "WORDPRESS_DB_PASSWORD=${WP_DB_PASS}"
  echo "WORDPRESS_DB_ROOT_PASSWORD=${WP_DB_ROOT_PASS}"
} >> .env

# Добавляем в Caddyfile, если нет
if ! grep -q "${WP_DOMAIN}" Caddyfile; then
  cat >> Caddyfile <<EOF

www.${WP_DOMAIN} {
  redir https://${WP_DOMAIN}{uri}
}

${WP_DOMAIN} {
  encode zstd gzip
  reverse_proxy wordpress:80
  header {
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    X-Frame-Options "SAMEORIGIN"
    X-Content-Type-Options "nosniff"
    Referrer-Policy "no-referrer-when-downgrade"
  }
}
EOF
fi

docker compose --profile wordpress up -d

echo "Готово: https://${WP_DOMAIN}"
echo "DB user: wpuser"
echo "DB pass: ${WP_DB_PASS}"
echo "DB root pass: ${WP_DB_ROOT_PASS}"
