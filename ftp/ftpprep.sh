#!/bin/bash
# Скрипт резервирования системы на FTP
# Подготовка FTP-сервера

if [ $# -lt 1 ]; then
 echo "$0 Backup path";
 exit 1;
fi;

backuppath=$1
ftpserver=someftpserver.somedomain.com;
host=$(hostname -s);

# Определяем пременные Аутентификации
ftp_usr=ftpusr
usr_pswd=$(cat /scripts/pass/$ftp_usr)
log=/tmp/ftpb.log;

#Подключение к ФТП-серверу
ftp -i -n $ftpserver << END_SCR 2> $log
quote USER $ftp_usr
quote PASS $usr_pswd
binary
mdelete $backuppath/old/*
rmdir $backuppath/old
rename $backuppath/current $backuppath/old
mkdir $backuppath/current
bye
END_SCR
