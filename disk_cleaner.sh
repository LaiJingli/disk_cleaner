#!/bin/bash
##update at 20190822

LOGS_PATH="/data/logs"
LOGS_BACK="/data/backup"
LOGS_DATE_TODAYS=$(date -d "0 day ago" +"%F")
LOGS_DATE_1DAYS_AGO=$(date -d "1 day ago" +"%F")
LOGS_DATE_2DAYS_AGO=$(date -d "2 day ago" +"%F")
LOGS_DATE_3DAYS_AGO=$(date -d "3 day ago" +"%F")
mkdir -pv $LOGS_BACK && chown www.www $LOGS_BACK
current_time="date +%Y-%m-%d_%H:%M:%S"
app_dir=`ls $LOGS_PATH`

backup_reserve_days_infinity=3650
backup_reserve_days_max=30
backup_reserve_days_medium=14
backup_reserve_days_min=7

rand_num=`date +%s%N`
rand_delay_minute=${rand_num: -1}

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
echo 当前数据盘使用率:$data_disk_useage_percent
echo backup_reserve_days:$backup_reserve_days

##防止同时执行日志压缩清理对业务造成影响，清理策略延迟n分钟执行
echo rand_delay_minute:$rand_delay_minute
sleep ${rand_delay_minute}m

##清理LOGS_PATH目录下的dump类的log
find $LOGS_PATH -maxdepth 1 -type f -name *.log* -mtime +7 -exec mv {} ${LOGS_BACK}/ \;
find $LOGS_BACK -maxdepth 1 -type f ! -name "*.gz"  -mtime +7|xargs gzip
find $LOGS_BACK  -type f -mtime +$backup_reserve_days -exec rm -f {} \;

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
    ##备份目录backup_reserve_days天之前log删除
    find $app_log_backup_dir  -type f -mtime +$backup_reserve_days -exec rm -f {} \;
    ##移动备份日志
    find $app_log_dir  -type f -name "*${LOGS_DATE_1DAYS_AGO}*" -exec mv {} ${app_log_backup_dir}/ \;
    find $app_log_dir  -type f -name "*${LOGS_DATE_2DAYS_AGO}*" -exec mv {} ${app_log_backup_dir}/ \;
    find $app_log_dir  -type f -name "*${LOGS_DATE_3DAYS_AGO}*" -exec mv {} ${app_log_backup_dir}/ \;
    find $app_log_dir  -type f -mtime +4 -exec mv {} ${app_log_backup_dir}/ \;
    ##备份目录非gz文件启动gz压缩
    find $app_log_backup_dir -type f ! -name "*.gz" |xargs gzip
    fi

   ##如果当前磁盘使用率已经大于80%，保险起见，每6个小时会对当天日志进行备份压缩(潜在风险是如果在白天高峰期执行的话会引起cpu略高、IO增加)
   #if [ $data_disk_useage_percent -ge 80 ];then
   #	find $app_log_dir  -type f -name "*${LOGS_DATE_TODAYS}*" -mmin +360 -exec mv {} ${app_log_backup_dir}/ \;
   #	find $app_log_backup_dir -type f ! -name "*.gz" |xargs gzip
   #fi 

done

chown -R www.www $LOGS_BACK
data_disk_useage_percent=`df -k /data| grep -v Filesystem| awk '{print int($5)}'`
echo 日志清理后数据盘使用率:$data_disk_useage_percent
echo end:`$current_time`
}


#log_move_and_gzip
log_move_and_gzip >> $LOGS_BACK/cut_logs.log


