#!/bin/bash

curdate=$(date '+%Y%m%d');
remotehost=111.111.111.111;
remoteport=22;
statspath=/stats/vds;
error=0;

user_backup=backup;
grp_backup=backup;
mailto=MonitoringBackup@somedomain.com;
mailfrom=$host@somedomain.com;
mailmsg=/tmp/vds_get.msg;

backuppath=/mnt/backup/vds;

prepare()
{
  # move old backups
  rm -r $backuppath/old;
  mv $backuppath/current $backuppath/old;

  # create new dirs
  mkdir -p $backuppath/current/{mysql,xfs} $backuppath/{md5sum,log} > /dev/null
  chown $user_backup:$grp_backup $backuppath $backuppath/current $backuppath/current/{mysql,xfs} $backuppath/{md5sum,log}
  chmod 775 $backuppath $backuppath/current $backuppath/current/{mysql,xfs} $backuppath/{md5sum,log};
}

get()
{
  # проверка доступности удаленного сервера
  su - backup -c "ssh -p $remoteport backup@$remotehost test -d /backup/mysql/" >> $mailmsg 2>&1;
  if [ $? -eq 255 ]; then
    echo "Error while accessing to the $remotehost" >> $mailmsg;
    error=1;
  else
    # vds mysql backup
    echo "$(date '+%Y%m%d_%H%M%S') Start copying mysql" >> $mailmsg;
    # Fixme: Files for copy. Check name and size
    su - $user_backup -c "scp -P $remoteport -r -p -c blowfish backup@$remotehost:/backup/mysql/current/* $backuppath/current/mysql/" >> $mailmsg 2>&1;
    chmod o+r $backuppath/current/mysql/*;
    echo "$(date '+%Y%m%d_%H%M%S') Result of copying mysql=$?" >> $mailmsg;

    # Fixme: Background

    # vds os & webroot backup
    echo "$(date '+%Y%m%d_%H%M%S') Start copying os & webroot" >> $mailmsg;
    su - $user_backup -c "scp -P $remoteport -r -p -c blowfish backup@$remotehost:/backup/xfs/current/* $backuppath/current/xfs/" >> $mailmsg 2>&1;
    chmod o+r $backuppath/current/xfs/*;
    echo "$(date '+%Y%m%d_%H%M%S') Result of copying os & webroot=$?" >> $mailmsg;

    # md5sum
    # Fixme: find last files
    echo "$(date '+%Y%m%d_%H%M%S') Start copying md5sum" >> $mailmsg;
    su - $user_backup -c "scp -P $remoteport -r -p -c blowfish backup@$remotehost:/stats/md5sum/md5sum_${curdate}* $backuppath/md5sum/" >> $mailmsg 2>&1;
    chmod o+r $backuppath/current/md5sum/*;
    echo "$(date '+%Y%m%d_%H%M%S') Result of copying md5sum=$?" >> $mailmsg;

    # logs
    echo "$(date '+%Y%m%d_%H%M%S') Start copying logs" >> $mailmsg;
    su - $user_backup -c "scp -P $remoteport -r -p -c blowfish backup@$remotehost:/stats/log/*-${curdate}* $backuppath/log/" >> $mailmsg 2>&1;
    chmod o+r $backuppath/current/log/*;
    echo "$(date '+%Y%m%d_%H%M%S') Result of copying logs=$?" >> $mailmsg;
  fi;
}


# Prepare head of mail message
echo "To: $mailto" > $mailmsg;
echo "Subject: Copying vds backup from server $remotehost" >> $mailmsg;

prepare;

echo "$(date '+%Y%m%d_%H%M%S') Start getting data from $remotehost" >> $mailmsg;

get;

echo "$(date '+%Y%m%d_%H%M%S') End getting data from $remotehost" >> $mailmsg;

# Send mail message
/usr/sbin/sendmail.postfix -oi -f $mailfrom $mailto < $mailmsg;

#rm $mailmsg

