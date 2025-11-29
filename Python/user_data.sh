#!/bin/bash
set -xe

# ================================
# VARIABLES (las completa crear_infra.py)
# ================================
APP_REPO_URL="__APP_REPO_URL__"
DB_HOST="__DB_HOST__"
DB_NAME="__DB_NAME__"
DB_USER="__DB_USER__"
DB_PASS="__DB_PASS__"
APP_USER_WEB="__APP_USER_WEB__"
APP_PASS_WEB="__APP_PASS_WEB__"

# ================================
# 1) Actualizar sistema e instalar Apache + PHP
# ================================
dnf clean all
dnf makecache
dnf -y update

dnf -y install httpd php php-cli php-fpm php-common php-mysqlnd mariadb105 git

systemctl enable --now httpd
systemctl enable --now php-fpm

# ================================
# 2) Configurar Apache para PHP-FPM (si no existe el archivo)
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

rm -rf /var/www/html/*

cp /tmp/apprepo/*.php /var/www/html/
cp /tmp/apprepo/*.html /var/www/html/
cp /tmp/apprepo/*.css /var/www/html/
cp /tmp/apprepo/*.js /var/www/html/

# ================================
# 4) Mover init_db.sql y README.md fuera del webroot
# ================================
if [ -f /tmp/apprepo/init_db.sql ]; then
  mv /tmp/apprepo/init_db.sql /var/www/init_db.sql
fi

if [ -f /tmp/apprepo/README.md ]; then
  mv /tmp/apprepo/README.md /var/www/README.md
fi

# ================================
# 5) Crear archivo .env con datos de RDS
# ================================
cat > /var/www/.env <<EOF
DB_HOST=${DB_HOST}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}

APP_USER=${APP_USER_WEB}
APP_PASS=${APP_PASS_WEB}
EOF

chmod 600 /var/www/.env
chown apache:apache /var/www/.env

# ================================
# 6) Ejecutar init_db.sql para crear tablas
# ================================
mysql -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" < /var/www/init_db.sql

# ================================
# 7) Permisos correctos
# ================================
chown -R apache:apache /var/www/html

# ================================
# 8) Reiniciar servicios
# ================================
systemctl restart httpd php-fpm

