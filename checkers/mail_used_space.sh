#!/bin/bash

logfile=/tmp/space_mail.log
curtime=$(date '+%Y%m%d -  %T');

echo $curtime >> $logfile
du -sch /mail/somedomain.local/* --exclude=/proc | grep "[0-9][0-9][0-9][MG]" >> $logfile
du -sch /mail/somedomain.local/* --exclude=/proc | grep "[0-9][0-9][0-9],[0-9][MG]" >> $logfile