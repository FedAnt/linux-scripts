#!/bin/bash
# Скрипт копирования BackUP системы

if [ $# -lt 1 ]; then
 echo "$0 Backup path";
 exit 1;
fi;

backuppath=$1;
remotehost=someserver.somedomain.local;
host=$(hostname -s);

# Определяем пременные Аутентификации
ftp_usr=ftpusr
usr_pswd=$(cat /scripts/pass/$ftp_usr)
log=/tmp/ftpb.log;

#Подключение к ФТП-серверу
ftp -i -n $remotehost << END_SCR 2> $log
quote USER $ftp_usr
quote PASS $usr_pswd
binary
lcd $backuppath/current
cd $backuppath/current
mput *
bye
END_SCR

#if [ -s $log ]; then
# (echo "Subject: Copying log file $type ERROR"; cat $log ) > $log.1;
# /usr/sbin/sendmail.postfix -oi -f $mailfrom $mailto < $log.1;
# rm $log.1;
#fi;

#rm $log;