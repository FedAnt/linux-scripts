#!/bin/bash

host=$(hostname -s);

mysql_user=backup;
mysql_pass=$(cat /scripts/pass/mysql);

binpath=/usr/bin;

backuppath=/backup/$host;
backuppathremote=/mnt/backup/$host;

mailto=MonitoringBackup@somedomain.local;
mailfrom=$host@somedomain.local;
mailmsg=/tmp/mysql_backup.msg;

errorflag=0;

curdate=$(date '+%Y%m%d');
curdatetime=$(date '+%Y%m%d_%H%M%S');

log()
{
 if [ -n "$msg" ]; then
  echo $(date '+%Y%m%d %H:%M:%S') $msg;
  echo $(date '+%Y%m%d %H:%M:%S') $msg >> $mailmsg;
 fi;
}

# Подготовка к резервному копированию на локальный сервер
prepare_local()
{
 # Удаляем старые резервные копии на локальном сервере
 rm -rf $backuppath/mysql/*;

 # Создаём новые директории
 mkdir -p $backuppath/mysql > /dev/null;
 chown -R backup:backup $backuppath/mysql;
 chmod -R 770 $backuppath/mysql;
}

# Подготовка к резервному копированию на удаленный сервер
prepare_remote()
{
 # Проверяем доступность удаленного сервера
 if [ -z "$(mount | grep /mnt/backup)" ]; then
  msg="Error: remote dir doesn't mount"; log;
  msg="Trying to remount"; log;
  mount /mnt/backup;
  if [ -z "$(mount | grep /mnt/backup)" ]; then
   msg="Error while remount remote dir"; log;
   errorflag=1;
  fi;
 fi;

 # Fixme: если предыдущее резервное копирование прошло успешно
 # Удаляем старые резервные копии на удаленном сервере
 if [ -d $backuppathremote/old/mysql ]; then
  rm -rf $backuppathremote/old/mysql;
 else
  # Создаём новые директории
  mkdir -p $backuppathremote/old/mysql > /dev/null;
  chown -R backup:backup $backuppathremote/old/mysql;
  chmod 770 $backuppathremote/old/mysql;
 fi;

 mv $backuppathremote/current/mysql $backuppathremote/old;

 # Создаём новые директории
 mkdir -p $backuppathremote/current/mysql > /dev/null;
 chown -R backup:backup $backuppathremote/current/mysql;
 chmod 770 $backuppathremote/current/mysql;
}


backup_database()
{
 # Резервировать БД в отдельные файлы
 for socket in '' '-S /var/lib/mysql/mysql_sams2.sock'; do

  # Инстанция
  if [ -z "$socket" ]; then
   instance=mysql;
  else
   instance=mysql_sams2;
   # Проверяем открыт ли сокет
   if ! [ -e ${socket#-S } ]; then
    echo Info: Socket $socket closed;
    continue;
   fi;
  fi;

  echo s=$socket i=$instance;

  for database in $($binpath/mysql $socket --user=$mysql_user --password=$mysql_pass --batch --execute='show databases' | egrep -v "information_schema|performance_schema|Database"); do
   echo d=$database;
   msg="Backupping instance $instance database $database"; log;
   mysqldumplog=/tmp/backup_mysql.log
   mysqldumpfile=$backuppath/mysql/${instance}_$database.gz;
   $binpath/mysqldump $socket --user=$mysql_user --password=$mysql_pass --log-error=$mysqldumplog $database | gzip -c > $mysqldumpfile;
   chown backup:backup $mysqldumpfile;
   chmod 640 $mysqldumpfile;
   if [ -s $mysqldumplog ]; then
    msg="Error: backupping instance $instance database $database failed"; log;
    msg=$(cat $mysqldumplog); log;
    errorflag=1;
   fi;
   rm $mysqldumplog;
  done;
 done;
}


replicate_database()
{
 databases="sams2";
 for database in $databases; do
  msg="Replicate database $database"; log;
  if [ $database = "sams2" ]; then
   mysqlzone_remote=mail1;
  fi;
 done;
}


# Копируем резервные копии на удаленный сервер
put_backup_remote()
{
 cp $backuppath/mysql/* $backuppathremote/current/mysql;

 # Проверяем результат выполнения копирования
 localsize=$(/usr/bin/du -sb $backuppath/mysql);
 localsize=$(echo $localsize | /usr/bin/cut -d ' ' -f 1);
 remotesize=$(/usr/bin/du -sb $backuppathremote/current/mysql);
 remotesize=$(echo $remotesize | /usr/bin/cut -d ' ' -f 1);

 if [ $localsize -eq $remotesize ]; then
  msg="Info: Transfer to remote server in $backuppathremote/current/mysql $remotesize bytes"; log;
 else
  msg="Error while copying backup to remote server"; log;
  msg="Info: Transfer to remote server in $backuppathremote/current/mysql $remotesize bytes instead of $localsize"; log;
  errorflag=1;
 fi;
}


send_mailmsg()
{
 # Время затраченное на резервное копирование
 msg="Time: $curdatetime - $(date +%H%M%S)"; log;

 # Изменяем тему письма в зависимости от результатов резервного копирования
 if [ $errorflag -eq 0 ]; then
  (echo "Subject: Creating and copying mysql databases to remote server ended successfully"; cat $mailmsg ) > $mailmsg.1;
 else
  (echo "Subject: Creating and copying mysql databases to remote server FAILED"; cat $mailmsg) > $mailmsg.1;
  # Отсылаем письмо
  /usr/sbin/sendmail.postfix -oi -f $mailfrom $mailto < $mailmsg.1;
 fi;

 rm $mailmsg $mailmsg.1
}


echo "To: $mailto" > $mailmsg;

prepare_local;

backup_database;

# Копировать БД на удалённый сервер
if [ $errorflag -ne 1 ]; then
 prepare_remote;
 put_backup_remote;
fi;

send_mailmsg;
exit $errorflag;
