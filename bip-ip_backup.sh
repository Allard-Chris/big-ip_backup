#!/bin/bash

### GLOBAL VARIABLES
current_date=$(date '+%s') # in epoch format
filename=$(echo $(uname -n)-$(date "+%m_%d_%y")) # name of the file to save
retention_days=20 # age files to keep (in day)
declare -a file_to_delete # array of name's files will be deleted if they are older than retention_days

### FTP VARIABLES
ftp_server=
ftp_user=
ftp_password=
ftp_dir=



### GET LIST OF FILE IN FTP_DIR | SAVE IT IN A TEMPORARY FILE
ftp -n $ftp_server <<End-Of-Session | awk '{print $1" "$6" "$7" "$8" "$9}' >> temporary.tmp
user $ftp_user $ftp_password
binary
cd $ftp_dir
ls -l
bye
End-Of-Session

### CHECK IN THE TEMPORARY FILE IF FILES ARE OLDER THAN DESIRED
while read line;
do
        echo "$line" | awk '{print $1}' | grep -q 'd'
        if [ "$?" = 1 ]
        then
                if echo "$line" | awk '{print $4}' | grep -q ':'
                then
                        file_date=$(echo $(echo "$line" | awk '{print $2" "$3" "}') $(date "+%Y"))
                else
                        file_date=$(echo $(echo "$line" | awk '{print $2" "$3" "$4}'))
                fi
                file_date=$(echo $(date -d "${file_date}" '+%s'))
                diff_day=$(((($current_date-$file_date))/86400))

                if [ "$diff_day" -gt "$retention_days" ]
                then
                        file_to_delete=( "${file_to_delete[@]}" "$(echo "$line" | awk '{print $5}')" )
                fi
        fi
done < temporary.tmp
rm temporary.tmp # delete temporary file

### IF FILES NEED TO BE DELETED BECAUSE OLDER THAN RETENTION_DAYS VARIABLE
if [ ! -z ${file_to_delete} ]
then
        echo ok
        ftp -n -i $ftp_server <<End-Of-Session
        user $ftp_user $ftp_password
        binary
        cd $ftp_dir
        mdel ${file_to_delete[@]}
        bye
End-Of-Session
fi

### CREATE COMPLETE BIG-IP SYSTEM BACKUP AND PUSH VIA FTP
tmsh save sys ucs $filename > /dev/null

ftp -n $ftp_server <<End-Of-Session
user $ftp_user $ftp_password
binary
cd $ftp_dir
put /var/local/ucs/$filename.ucs /$ftp_dir/$filename.ucs
bye
End-Of-Session

rm /var/local/ucs/$filename.ucs # delete local backup file