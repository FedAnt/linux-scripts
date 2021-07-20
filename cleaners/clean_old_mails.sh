#!/bin/bash

# Папка по которой осуществляем поиск
find_str="/mail/some-domain.ru"
# Подпапки в которых ищем файлы для удаления
subfolders=(cur new tmp)

cd $find_str

# Пробегаемся по всем почтовым ящикам
for i in `find ${find_str} -maxdepth 1 -type d`
do
    # Исключить папку info
    if [ $i == "${find_str}/info" ]; then continue; fi;
    echo -e "$i"
    # Пробегаем по подпапкам
    for m in ${subfolders[*]}; do
        # Исключить корневую папку
        if [ $i == $find_str ]; then continue; fi;
        cd ${i}/${m}
        # Удаление фалов старше
        #       730 дней - 2 года
        #       1095 дней - 3 года
        #       1825 дней - 5 лет
        find "${i}/${m}" -type f -name "*" -mtime +1095 -print -exec rm {} \;
        cd ..
    done

    cd ..
done
