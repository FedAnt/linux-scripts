#!/bin/bash

mysql_pass=$(cat /scripts/pass/mysql);
scripts_path=/scripts/dspam;

# Хранить журналы в течении, дней
log_days=60;
# Хранить сигнатуры в течении, дней
sig_days=30;

# Отчистить журналы
#dspam_logrotate -a $log_days -d /var/log/dspam.log;

# Отчистить БД сигнатур
# Вариант 1: напрямую в БД dspam в MySQL
mysql --user=root --password=$mysql_pass dspam < $scripts_path/dspam_purge.sql > /dev/null 2>&1;

# Вариант 2: через утилиту dspam_clean
#/usr/local/bin/dspam_clean -a -s$sig_days -p$sig_days -u$sig_days,$sig_days,$sig_days,$sig_days;
# Удалить всё старше 4 дней
#/usr/local/bin/dspam_clean -s4
