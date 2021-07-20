#!/bin/bash

host=$(hostname -s);
backuppath=/backup/$host;
backuppathremote=/mnt/backup/$host;
user_backup=backup;
grp_backup=backup;

mailto=MonitoringBackup@somedomain.local;
mailfrom=$host@somedomain.local;
mailmsg=/tmp/ext4_backup.msg;


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
 rm -rf $backuppath/ext4/*;

 # Создаём новые директории
 mkdir -p $backuppath/ext4 > /dev/null;
 chown -R $user_backup:$grp_backup $backuppath/ext4;
 chmod -R 770 $backuppath/ext4;
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
 if [ -d $backuppathremote/old/ext4 ]; then
  rm -rf $backuppathremote/old/ext4;
 else
  # Создаём новые директории
  mkdir -p $backuppathremote/old/ext4 > /dev/null;
  chown -R $user_backup:$grp_backup $backuppathremote/old/ext4;
  chmod 770 $backuppathremote/old/ext4;
 fi;

 mv $backuppathremote/current/ext4 $backuppathremote/old;

 # Создаём новые директории
 mkdir -p $backuppathremote/current/ext4 > /dev/null;
 chown -R $user_backup:$grp_backup $backuppathremote/current/ext4;
 chmod 770 $backuppathremote/current/ext4;
}


# Резервное копирование
backup()
{
 # Исключаем из резервного копирования директории
 for exclide_dir in /backup /cache /export /proc /dev /tmp /sys /stats /mnt; do
  exclude_ops="$exclude_ops --exclude=$exclide_dir/*";
 done;
 backuperr=/tmp/ext4_backup.log;

 # root fs
 tar cfpP - / $exclude_ops | pigz -c > $backuppath/ext4/root_$curdatetime.tgz 2>$backuperr;
 # mail
 tar cfpP - /mail | pigz -c > $backuppath/ext4/mail_$curdatetime.tgz 2>>$backuperr;
 # mysql
 tar cfpP - /mysql | pigz -c > $backuppath/ext4/mysql_$curdatetime.tgz 2>>$backuperr;

 # Устанавливаем права на резервную копию
 chown $user_backup:$grp_backup $backuppath/ext4/*_$curdatetime.tgz;
 chmod 640 $backuppath/ext4/*_$curdatetime.tgz;

 # Вставляем журнал в письмо
 cat $backuperr | grep -v ": socket ignored" > $backuperr.1;
 if [ -s $backuperr.1 ]; then
  msg="Error while backupping ext4"; log;
  msg=$(cat $backuperr.1); log;
  errorflag=1;
 fi;
 rm $backuperr $backuperr.1;
}


# Копирование резервных копий на удаленный сервер
put_backup_remote()
{
 cp $backuppath/ext4/* $backuppathremote/current/ext4;

 # Проверяем результат выполнения копирования
 localsize=$(/usr/bin/du -sb $backuppath/ext4);
 localsize=$(echo $localsize | /usr/bin/cut -d ' ' -f 1);
 remotesize=$(/usr/bin/du -sb $backuppathremote/current/ext4);
 remotesize=$(echo $remotesize | /usr/bin/cut -d ' ' -f 1);

 if [ $localsize -eq $remotesize ]; then
  msg="Info: Transfer to remote server in $backuppathremote/current/ext4 $remotesize bytes"; log;
 else
  msg="Error while copying backup to remote server"; log;
  msg="Info: Transfer to remote server in $backuppathremote/current/ext4 $remotesize bytes instead of $localsize"; log;
  errorflag=1;
 fi;
}


# Отсылка результата выполнения резервного копирования по почте
send_mailmsg()
{
 # Время затраченное на резервное копирование
 msg="Time: $curdatetime - $(date +%H%M%S)"; log;

 # Изменяем тему письма в зависимости от результатов резервного копирования
 if [ $errorflag -eq 0 ]; then
  (echo "Subject: $host Creating and copying ext4 to remote server ended successfully"; cat $mailmsg ) > $mailmsg.1;
 else
  (echo "Subject: $host Creating and copying ext4 to remote server FAILED"; cat $mailmsg) > $mailmsg.1;
 fi;

 mv -f $mailmsg.1 $mailmsg;

 /usr/sbin/sendmail.postfix -oi -f $mailfrom $mailto < $mailmsg;
 #rm $mailmsg;
}

echo "To: $mailto" > $mailmsg;

# Подготовка к резервному копированию
prepare_local;

# Резервное копирование
backup;

# Копирование резервных копии на удалённый сервер
if [ $errorflag -ne 1 ]; then
 prepare_remote;
 put_backup_remote;
fi;

# Отсылка результата выполнения резервного копирования по почте
send_mailmsg;

exit $errorflag;
