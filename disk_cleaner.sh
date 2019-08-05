#!/bin/bash

LOGS_PATH="/data/logs"
LOGS_BACK="/data/backup"
LOGS_DATE=$(date -d "1 day ago" +"%F")
mkdir -pv $LOGS_BACK && chown www.www $LOGS_BACK
current_time="date +%Y-%m-%d_%H:%M:%S"
app_dir=`ls $LOGS_PATH`

backup_reserve_days_infinity=3650
backup_reserve_days_max=30
backup_reserve_days_medium=20
backup_reserve_days_min=10

##根据数据盘当前容量，自动判断备份保留天数
data_disk_useage_percent=`df -k /data| grep -v Filesystem| awk '{print int($5)}'`
if [ $data_disk_useage_percent -ge 80 ];then
    backup_reserve_days=$backup_reserve_days_min
elif  [ $data_disk_useage_percent -ge 70 ];then
    backup_reserve_days=$backup_reserve_days_medium
elif  [ $data_disk_useage_percent -ge 60 ];then
    backup_reserve_days=$backup_reserve_days_max
else
    backup_reserve_days=$backup_reserve_days_infinity
fi


log_move_and_gzip () {
echo ----------
echo start:`$current_time`
echo backup_reserve_days:$backup_reserve_days
##所有应用的log都需要清理
for i in ${app_dir[*]};do
    app_log_dir=$LOGS_PATH/$i
    app_log_backup_dir=$LOGS_BACK/$i

    ##如果是目录，且符合正则，移动到backup目录，进行压缩
    if [ -d "$app_log_dir" ];then
        #echo  "$app_log_dir 文件夹存在"
    ##备份目录是否存在app_dir，不存在则创建
    if [ ! -d "$app_log_backup_dir" ];then
        echo "$app_log_backup_dir 不存在,创建"
        mkdir -pv $app_log_backup_dir 
    fi
    ##
    find $app_log_dir -maxdepth 1 -type f -name "*${LOGS_DATE}*" -exec mv {} ${app_log_backup_dir}/ \;
    find $app_log_dir -maxdepth 1 -type f -mtime +7 -exec mv {} ${app_log_backup_dir}/ \;
    ##备份目录非gz文件启动gz压缩
    find $app_log_backup_dir -type f ! -name "*.gz" |xargs gzip
    ##备份目录backup_reserve_days天之前log删除
    find $app_log_dir -maxdepth 1 -type f -mtime +$backup_reserve_days -exec rm -f {} \;
    fi
done

chown -R www.www $LOGS_BACK
echo
echo end:`$current_time`
}

#log_move_and_gzip
log_move_and_gzip >> $LOGS_BACK/cut_logs.log


