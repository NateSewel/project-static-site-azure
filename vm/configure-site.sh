#!/usr/bin/env bash
set -euo pipefail
apt-get update
apt-get install -y nginx unzip
mkdir -p /var/www/html
# scp or wget a zip of your site to /tmp/site.zip then:
# unzip -o /tmp/site.zip -d /var/www/html
chown -R www-data:www-data /var/www/html
systemctl enable nginx
systemctl restart nginx
