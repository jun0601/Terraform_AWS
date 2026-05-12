#!/bin/bash
hostnamectl --static set-hostname Seoul-AWS-WebSrv1
dnf -y install php php-cli php-mysqlnd
dnf -y install httpd php-fpm mariadb1011-client-utils
systemctl enable --now httpd php-fpm
mkdir /var/www/inc
curl -o /var/www/inc/dbinfo.inc https://cloudneta-book.s3.ap-northeast-2.amazonaws.com/chapter8/dbinfo.inc
curl -o /var/www/html/db.php https://cloudneta-book.s3.ap-northeast-2.amazonaws.com/chapter8/db.php
sed -i "s/dbsrv.idcseoul.internal/${db_address}/g" /var/www/html/db.php
sed -i "s/gasida/${db_user}/g" /var/www/html/db.php
sed -i "s/qwe123/${db_password}/g" /var/www/html/db.php
rm -rf /var/www/html/index.html
echo "<h1>CloudNet@ FullLab - SeoulRegion - NEW - Websrv1</h1>" > /var/www/html/index.html
echo "<h1>NEW-ALB-DNS: ${alb_dns}</h1>" >> /var/www/html/index.html
echo "<h1>NEW-DB-PORT: ${db_port}</h1>" >> /var/www/html/index.html
echo "<h1>NEW-DB-User: ${db_user}</h1>" >> /var/www/html/index.html