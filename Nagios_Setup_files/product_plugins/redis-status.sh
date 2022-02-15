#!/bin/bash

#Redis status
SERV="$1"
METRIC="$2"
PORT="$4"
DB="$3"
PATH=/usr/bin:/bin:$PATH

if [[ -z "$1" ]]; then
    echo "Please set server"
    exit 1
fi

CACHETTL="10"  
CACHE="/tmp/redis-status-`/bin/echo $SERV | /usr/bin/md5sum | /usr/bin/cut -d" " -f1`.cache"
if [ -s "$CACHE" ]; then
    TIMECACHE=`/usr/bin/stat -c"%Z" "$CACHE"`
else
    TIMECACHE=0
fi
TIMENOW=`/bin/date '+%s'`


FIRST_ELEMENT=1
function json_head {
    printf "{";
    printf "\"data\":[";    
}

function json_end {
    printf "]";
    printf "}";
}

function check_first_element {
    if [[ $FIRST_ELEMENT -ne 1 ]]; then
        printf ","
    fi
    FIRST_ELEMENT=0
}

function databse_detect {
    json_head
    for dbname in $LIST_DATABSE
    do
        local dbname_t=$(echo $dbname| sed 's!\n!!g')
        check_first_element
        printf "{"
        printf "\"{#DBNAME}\":\"$dbname_t\""
        printf "}"
    done
    json_end
}


command="INFO"

case $METRIC in

      'primitive_req_count')
         command="ZCARD exp"
       ;;
       
       'primitive_inv_req_count')
         command="eval \"local sum = 0;local matches = redis.call(\'KEYS\', \'invocationkey:*\'); for _,key in ipairs(matches) do sum = sum + 1 ; end; return sum\" 0"
       ;;

      'primitive_expiry_count')
	command="zcount exp -inf $(date +%s)"
       ;;

      'primitive_expiry_leak')
	command="eval \"local backlog_time = ((tonumber($TIMENOW)* 1000) - 18000000); local leak_count = redis.call(\'ZCOUNT\', \'exp\', \'-inf\', $TIMENOW); return leak_count; \" 0"
      ;;		

      '*')
         command="INFO"
       ;;

esac


if [ "$(($TIMENOW - $TIMECACHE))" -gt "$CACHETTL" ]; then
  (/bin/echo -en "$command\r\n"; /bin/sleep 1;) | /usr/bin/nc -w1 $SERV $PORT > $CACHE || exit 1  
fi

case $METRIC in
    'primitive_req_count')
        (echo -en "$command\r\n"; sleep 1;) | /usr/bin/nc -w1 $SERV $PORT  |  /usr/bin/cut -d':' -f2
        ;;     
     'primitive_inv_req_count')
        (echo -en "$command\r\n"; sleep 1;) | /usr/bin/nc -w1 $SERV $PORT  |  /usr/bin/cut -d':' -f2
        ;;
    'primitive_expiry_count')
	(echo -en "$command\r\n"; sleep 1;) | /usr/bin/nc -w1 $SERV $PORT | /usr/bin/cut -d':' -f2
	;;                   
    'primitive_expiry_leak')
	(echo -en "$command\r\n"; sleep 1;) | /usr/bin/nc -w1 $SERV $PORT | /usr/bin/cut -d':' -f2
	;;                   
    'redis_version')
        cat $CACHE | grep "redis_version:" | /usr/bin/cut -d':' -f2        
        ;;            
    'redis_git_sha1')
        cat $CACHE | grep "redis_git_sha1:" | /usr/bin/cut -d':' -f2
        ;;
    'redis_git_dirty')
        cat $CACHE | grep "redis_git_dirty:" | /usr/bin/cut -d':' -f2
        ;;
    'redis_mode')
        cat $CACHE | grep "redis_mode:" | /usr/bin/cut -d':' -f2
        ;;
    'arch_bits')
        cat $CACHE | grep "arch_bits:" | /usr/bin/cut -d':' -f2
        ;;
    'multiplexing_api')
        cat $CACHE | grep "multiplexing_api:" | /usr/bin/cut -d':' -f2
        ;;
    'gcc_version')
        cat $CACHE | grep "gcc_version:" | /usr/bin/cut -d':' -f2
        ;;
    'uptime_in_seconds')
        cat $CACHE | grep "uptime_in_seconds:" | /usr/bin/cut -d':' -f2
        ;;
    'lru_clock')
        cat $CACHE | grep "lru_clock:" | /usr/bin/cut -d':' -f2
        ;;            
    'connected_clients')
        cat $CACHE | grep "connected_clients:" | /usr/bin/cut -d':' -f2
        ;;
    'client_longest_output_list')
        cat $CACHE | grep "client_longest_output_list:" | /usr/bin/cut -d':' -f2
        ;;
    'client_biggest_input_buf')
        cat $CACHE | grep "client_biggest_input_buf:" | /usr/bin/cut -d':' -f2
        ;;
    'used_memory')
        cat $CACHE | grep "used_memory:" | /usr/bin/cut -d':' -f2
        ;;
    'used_memory_peak')
        cat $CACHE | grep "used_memory_peak:" | /usr/bin/cut -d':' -f2
        ;;        
    'mem_fragmentation_ratio')
        cat $CACHE | grep "mem_fragmentation_ratio:" | /usr/bin/cut -d':' -f2
        ;;
    'loading')
        cat $CACHE | grep "loading:" | /usr/bin/cut -d':' -f2
        ;;            
    'rdb_changes_since_last_save')
        cat $CACHE | grep "rdb_changes_since_last_save:" | /usr/bin/cut -d':' -f2
        ;;
    'rdb_bgsave_in_progress')
        cat $CACHE | grep "rdb_bgsave_in_progress:" | /usr/bin/cut -d':' -f2
        ;;
    'aof_rewrite_in_progress')
        cat $CACHE | grep "aof_rewrite_in_progress:" | /usr/bin/cut -d':' -f2
        ;;
    'aof_enabled')
        cat $CACHE | grep "aof_enabled:" | /usr/bin/cut -d':' -f2
        ;;
    'aof_rewrite_scheduled')
        cat $CACHE | grep "aof_rewrite_scheduled:" | /usr/bin/cut -d':' -f2
        ;;
    'total_connections_received')
        cat $CACHE | grep "total_connections_received:" | /usr/bin/cut -d':' -f2
        ;;            
    'total_commands_processed')
        cat $CACHE | grep "total_commands_processed:" | /usr/bin/cut -d':' -f2
        ;;
    'instantaneous_ops_per_sec')
        cat $CACHE | grep "instantaneous_ops_per_sec:" | /usr/bin/cut -d':' -f2
        ;;
    'rejected_connections')
        cat $CACHE | grep "rejected_connections:" | /usr/bin/cut -d':' -f2
        ;;
    'expired_keys')
        cat $CACHE | grep "expired_keys:" | /usr/bin/cut -d':' -f2
        ;;
    'evicted_keys')
        cat $CACHE | grep "evicted_keys:" | /usr/bin/cut -d':' -f2
        ;;
    'keyspace_hits')
        cat $CACHE | grep "keyspace_hits:" | /usr/bin/cut -d':' -f2
        ;;        
    'keyspace_misses')
        cat $CACHE | grep "keyspace_misses:" | /usr/bin/cut -d':' -f2
        ;;
    'pubsub_channels')
        cat $CACHE | grep "pubsub_channels:" | /usr/bin/cut -d':' -f2
        ;;        
    'pubsub_patterns')
        cat $CACHE | grep "pubsub_patterns:" | /usr/bin/cut -d':' -f2
        ;;             
    'latest_fork_usec')
        cat $CACHE | grep "latest_fork_usec:" | /usr/bin/cut -d':' -f2
        ;; 
    'role')
        cat $CACHE | grep "role:" | /usr/bin/cut -d':' -f2
        ;;
    'connected_slaves')
        cat $CACHE | grep "connected_slaves:" | /usr/bin/cut -d':' -f2
        ;;          
    'used_cpu_sys')
        cat $CACHE | grep "used_cpu_sys:" | /usr/bin/cut -d':' -f2
        ;;  
    'used_cpu_user')
        cat $CACHE | grep "used_cpu_user:" | /usr/bin/cut -d':' -f2
        ;;
    'used_cpu_sys_children')
        cat $CACHE | grep "used_cpu_sys_children:" | /usr/bin/cut -d':' -f2
        ;;             
    'used_cpu_user_children')
        cat $CACHE | grep "used_cpu_user_children:" | /usr/bin/cut -d':' -f2
        ;;
    'blocked_clients')
        cat $CACHE | grep "blocked_clients:" | /usr/bin/cut -d':' -f2
          ;;
   'used_memory_rss')
        cat $CACHE | grep "used_memory_rss:" | /usr/bin/cut -d':' -f2 
        ;;        
   'key_space_db_keys')
        cat $CACHE | grep $DB:|/usr/bin/cut -d':' -f2|/usr/bin/awk -F, '{print $1}'|/usr/bin/cut -d'=' -f2
        ;;
   'key_space_db_expires')
        cat $CACHE | grep $DB:|/usr/bin/cut -d':' -f2|/usr/bin/awk -F, '{print $2}'|/usr/bin/cut -d'=' -f2 
        ;;
    'list_key_space_db')
        LIST_DATABSE=`cat $CACHE | grep '^db.:'|/usr/bin/cut -d: -f1`
        databse_detect
        ;;                                                     
    *)   
        echo "Not selected metric"
        exit 0
        ;;
esac
