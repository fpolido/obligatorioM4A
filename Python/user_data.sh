#!/bin/bash
set -xe

# ================================
# VARIABLES (reemplazadas desde Python)
# ================================
APP_REPO_URL="__APP_REPO_URL__"
DB_HOST="__DB_HOST__"
DB_NAME="__DB_NAME__"
DB_APP_USER="__DB_APP_USER__"
DB_APP_PASSWORD="__DB_APP_PASSWORD__"
DB_MASTER_USER="__DB_MASTER_USER__"
DB_MASTER_PASSWORD="__DB_MASTER_PASSWORD__"
APP_ADMIN_USER="__APP_ADMIN_USER__"
APP_ADMIN_PASSWORD="__APP_ADMIN_PASSWORD__"
APP_DIR="/var/www"

# ================================
# 1) Actualizar sistema e instalar Apache + PHP
# ================================
sudo dnf clean all
sudo dnf makecache
sudo dnf -y update
sudo dnf -y install httpd php php-cli php-fpm php-common php-mysqlnd mariadb105 git

sudo systemctl enable --now httpd
sudo systemctl enable --now php-fpm

# ================================
# 2) Configurar Apache para PHP-FPM
# ================================
if [ ! -f /etc/httpd/conf.d/php-fpm.conf ]; then
cat > /etc/httpd/conf.d/php-fpm.conf <<'EOF'
<FilesMatch \.php$>
  SetHandler "proxy:unix:/run/php-fpm/www.sock|fcgi://localhost/"
</FilesMatch>
EOF
fi

# ================================
# 3) Clonar la aplicación
# ================================
rm -rf /tmp/apprepo
git clone "$APP_REPO_URL" /tmp/apprepo

mkdir -p ${APP_DIR}/html
rm -rf ${APP_DIR}/html/*

rsync -av --exclude 'init_db.sql' --exclude 'README.md' /tmp/apprepo/ ${APP_DIR}/html/

# ================================
# 4) Mover init_db.sql y README.md fuera del webroot
# ================================
if [ -f /tmp/apprepo/init_db.sql ]; then
  mv /tmp/apprepo/init_db.sql ${APP_DIR}/init_db.sql
fi

if [ -f /tmp/apprepo/README.md ]; then
  mv /tmp/apprepo/README.md /var/www/README.md
fi

# ================================
# 5) Crear base de datos y usuario de app
# ================================
mysql -h "${DB_HOST}" -u "${DB_MASTER_USER}" -p"${DB_MASTER_PASSWORD}" <<EOSQL
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_APP_USER}'@'%' IDENTIFIED BY '${DB_APP_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_APP_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL

# ================================
# 6) Ejecutar init_db.sql con el usuario de app
# ================================
mysql -h "${DB_HOST}" -u "${DB_MASTER_USER}" -p"${DB_MASTER_PASSWORD}" < ${APP_DIR}/init_db.sql

# ================================
# 7) Crear archivo .env
# ================================
cat > ${APP_DIR}/.env <<EOF
DB_HOST=${DB_HOST}
DB_NAME=${DB_NAME}
DB_USER=${DB_APP_USER}
DB_PASS=${DB_APP_PASSWORD}

APP_USER=${APP_ADMIN_USER}
APP_PASS=${APP_ADMIN_PASSWORD}
EOF

chown apache:apache ${APP_DIR}/.env
chmod 600 ${APP_DIR}/.env

# ================================
# 8) Permisos correctos en webroot
# ================================
chown -R apache:apache ${APP_DIR}

# ================================
# 9) Reiniciar servicios
# ================================
sudo systemctl restart httpd php-fpm
