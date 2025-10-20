#!/usr/bin/env bash
set -euo pipefail

# Install dependencies
apt-get update -y
apt-get install -y nginx git unzip

# Setup web directory
mkdir -p /var/www/html
rm -rf /var/www/html/*

# Clone repo (manual execution)
git clone --depth 1 https://github.com/NateSewel/project-static-site-azure.git /tmp/site-repo
cp -r /tmp/site-repo/* /var/www/html/
chown -R www-data:www-data /var/www/html
rm -rf /tmp/site-repo

# Enable and restart nginx
systemctl enable nginx
systemctl restart nginx

echo "✅ Site setup completed."
