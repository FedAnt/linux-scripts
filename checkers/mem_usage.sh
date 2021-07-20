#!/bin/bash

echo pid size rss pss shared_clean shared_dirty

for pid in $(ps -ef | awk '{print $2}'); do
 if [ -f /proc/$pid/smaps ]; then
  size=$(cat /proc/$pid/smaps | grep -m 1 -e ^Size: | awk '{print $2}');
  rss=$(cat /proc/$pid/smaps | grep -m 1 -e ^Rss: | awk '{print $2}');
  pss=$(cat /proc/$pid/smaps | grep -m 1 -e ^Pss: | awk '{print $2}');
  shc=$(cat /proc/$pid/smaps | grep -m 1 -e '^Shared_Clean:' | awk '{print $2}')
  shd=$(cat /proc/$pid/smaps | grep -m 1 -e '^Shared Dirty:' | awk '{print $2}')
  echo $pid $size $rss $pss $shcl $shd
 fi
done
