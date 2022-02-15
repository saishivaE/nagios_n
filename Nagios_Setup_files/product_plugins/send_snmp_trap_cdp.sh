#!/bin/bash
#
# Called from: Nagios & from platform internal scripts
# Sent to: NetAct
# Parameters for this script:
#   SEVERITY: (CRITICAL|WARNING|OK)
#   HOSTNAME: node IP where the alarm comes from
#   MESSAGE_DESC: short alarm description (equals to service_description field in services.cfg)
#   MESSAGE_DETAIL: detailed alarm description
#                   created by NAGIOS in case of nagios plugin calls or own scripts output
#   NETACT: SERVER:IP of remote NetAct server in OAM vlan

SEVERITY=$1
HOST_NAME=${2:-localhost}
IP=${3:-127.0.0.1}
MESSAGE_DESC=$4
HOST_GROUP_NAME=$5
MESSAGE_DETAIL=$6
NETACT=${7:-localhost}

OID_CDP=1.3.6.1.4.1.28458.1.44
MIB="SNMP-CDP-MIB"

# Arguments: 1 FM trap type, 2 Alarm ID number, 3 Severity, 4 Agreed alarm text, 5 Additional free alarm text
set_messages()
{
  TRAP_TYPE="$MIB::$1"
  ALARM_NUM="$MIB::cdpAlarmNumber i $2"
  NOTIF_ID="$MIB::cdpNotificationId s ${HOST_NAME}:${IP}"
  ALARM_TEXT="$4"
  ALARM_ADD="$5"
  UNIX_TIME=`date +%s`
  ALARM_TIME="$MIB::cdpAlarmTime s ${UNIX_TIME}"

#Translate common severity naming to Netact specific
  case $3 in
        "OK"|"UP")
                A_SEVERITY="CLEARED";;
        "CRITICAL"|"DOWN"|"UNREACHABLE")
                A_SEVERITY="MAJOR";;
        "WARNING")
                A_SEVERITY="MINOR";;
        *)
            A_SEVERITY="CLEARED";; ###if SEVERITY is not appropriate, shall we quit ???
  esac
  A_SEVERITY="$MIB::cdpSeverity s ${A_SEVERITY}"
}

#Main case branch
case $MESSAGE_DESC in
        "PING"*|"SSH"*)
		        [[ "$HOST_NAME" =~ "load_balancer" ]] && set_messages "lbnotReachableTrap" "10004" "$SEVERITY" "Load balancer node unreachable" "Load balancer node is unreachable"
                [[ "$HOST_GROUP_NAME" =~ "oracle_db_servers" ]] && set_messages "dbHostUnreachableTrap" "11001" "$SEVERITY" "DB node unreachable" "A specific DB node is unreachable"
                [[ "$HOST_GROUP_NAME" =~ "oracle_gg_servers" ]] && set_messages "geoSiteUnreachableTrap" "15001" "$SEVERITY" "GoldenGate node unreachable" "A specific GoldenGate node is unreachable"
                [[ "$HOST_GROUP_NAME" =~ "mysql_db_servers" ]] && set_messages "dbHostUnreachableTrap" "11001" "$SEVERITY" "DB node unreachable" "A specific DB node is unreachable"
                [[ "$HOST_GROUP_NAME" =~ "emg_servers" ]] && set_messages "smsHostUnreachableTrap" "12001" "$SEVERITY" "EMG node unreachable" "A specific EMG node is unreachable"
                [[ "$HOST_GROUP_NAME" =~ "redis_servers" ]] && set_messages "redisHostUnreachableTrap" "13001" "$SEVERITY" "Redis server unreachable" "A specific Redis Server is unreachable"
                [[ "$HOST_GROUP_NAME" =~ "redis_sentinel_servers" ]] && set_messages "redisSentinelHostUnreachableTrap" "14001" "$SEVERITY" "Redis Sentinel server unreachable" "A specific Redis Sentinel Server is unreachable"
                [[ "$HOST_GROUP_NAME" =~ "cdp_servers" ]] && set_messages "hostUnreachableTrap" "10001" "$SEVERITY" "one of CDP node unreachable" "A specific CDP internal node is unreachable"
		;;
        "CDP Node Up"*)
                set_messages "hostUnreachableTrap" "10001" "$SEVERITY" "one of CDP node unreachable" "A specific CDP internal node is unreachable"
		;;
        "EMG Node Up"*)
                set_messages "smsHostUnreachableTrap" "12001" "$SEVERITY" "EMG node unreachable" "A specific EMG node is unreachable"
		;;
        "Oracle DB Node Up"*|"MySQL DB Node Up"*)
                set_messages "dbHostUnreachableTrap" "11001" "$SEVERITY" "DB node unreachable" "A specific DB node is unreachable"
		;;
        "REDIS Node Up"*)
                set_messages "redisHostUnreachableTrap" "13001" "$SEVERITY" "Redis server unreachable" "A specific Redis Server is unreachable"
		;;
        "REDIS Sentinel Node Up"*)
                set_messages "redisSentinelHostUnreachableTrap" "14001" "$SEVERITY" "Redis Sentinel server unreachable" "A specific Redis Sentinel Server is unreachable"
		;;
        "Oracle GoldenGate Node Up"*)
                set_messages "geoSiteUnreachableTrap" "15001" "$SEVERITY" "GoldenGate node unreachable" "A specific GoldenGate node is unreachable"
		;;
        "Current Load"*)
                [[ "$HOST_GROUP_NAME" =~ "oracle_db_servers" ]] && set_messages "dbCpuLoadTrap" "11002" "$SEVERITY" "CPU load issue" "High CPU load on DB node: $MESSAGE_DETAIL"
		        [[ "$HOST_GROUP_NAME" =~ "mysql_db_servers" ]] && set_messages "dbCpuLoadTrap" "11002" "$SEVERITY" "CPU load issue" "High CPU load on DB node: $MESSAGE_DETAIL"
                [[ "$HOST_GROUP_NAME" =~ "emg_servers" ]] && set_messages "smsCpuLoadTrap" "12002" "$SEVERITY" "CPU load issue" "High CPU load on EMG node: $MESSAGE_DETAIL"
                [[ "$HOST_GROUP_NAME" =~ "redis_servers" ]] && set_messages "redisCpuLoadTrap" "13002" "$SEVERITY" "CPU load issue" "High CPU load on Redis server node: $MESSAGE_DETAIL"
                [[ "$HOST_GROUP_NAME" =~ "cdp_servers" ]] && set_messages "cpuLoadTrap" "10002" "$SEVERITY" "CPU load issue" "High CPU load on CDP node: $MESSAGE_DETAIL"
		;;
        "Disk Usage"*)
                [[ "$HOST_GROUP_NAME" =~ "oracle_db_servers" ]] && set_messages "dbDiskCapacityTrap" "11003" "$SEVERITY" "Disk capacity issue" "Disk capacity reached a critical limit on DB node"
		        [[ "$HOST_GROUP_NAME" =~ "mysql_db_servers" ]] && set_messages "dbDiskCapacityTrap" "11003" "$SEVERITY" "Disk capacity issue" "Disk capacity reached a critical limit on DB node"
                [[ "$HOST_GROUP_NAME" =~ "emg_servers" ]] && set_messages "smsDiskCapacityTrap" "12003" "$SEVERITY" "Disk capacity issue" "Disk capacity reached a critical limit on EMG node"
                [[ "$HOST_GROUP_NAME" =~ "redis_servers" ]] && set_messages "redisDiskCapacityTrap" "13003" "$SEVERITY" "Disk capacity issue" "Disk capacity reached a critical limit on Redis server node"
                [[ "$HOST_GROUP_NAME" =~ "cdp_servers" ]] && set_messages "diskCapacityTrap" "10003" "$SEVERITY" "Disk capacity issue" "Disk capacity reached a critical limit on CDP node"
		;;

        "DB availability"*|"MySQL DB availability"*)
                set_messages "dbHostUnreachableTrap" "11001" "$SEVERITY" "DB is unavailable" "DB is not available due to: $MESSAGE_DETAIL"
		;;
        "DB tablespace usage"*|"MySQL DB tablespace usage"*)
                set_messages "dbTablespaceCapacityTrap" "11005" "$SEVERITY" "DB tablespace issue" "Tablespace capacity reached a critical limit on DB node: $MESSAGE_DETAIL"
		;;
        "Outgoing SMPP"*)
                set_messages "smscServerUnreachableTrap" "12005" "$SEVERITY" "SMSC unreachable" "SMSC center is unreachable from EMG server: $MESSAGE_DETAIL"
		;;
        "REDIS Failover"*)
                set_messages "redisMasterFailoverTrap" "13005" "$SEVERITY" "Redis server failover" "Failover happened on Redis Server: $MESSAGE_DETAIL"
		;;
        "CDP Application Deployment"*)
                set_messages "hostUnreachableTrap" "10005" "$SEVERITY" "CDP application unreachable" "CDP application is not deployed on a CDP node"
		;;
		"Device Look up Failure"*)
                set_messages "deviceLookUpFailure" "10006" "$SEVERITY" "Device Look up Failure" "Device Look up Failure : $MESSAGE_DETAIL"
		;;
		"APNS Failure"*)
                set_messages "apnsFailure" "10007" "$SEVERITY" "APNS Failure" "APNS Failure : $MESSAGE_DETAIL"
		;;
		"Device Authentication Failure on ES"*)
                set_messages "deviceAuthentication" "10008" "$SEVERITY" "Device Authentication Failure" "Device Authentication Failure on ES : $MESSAGE_DETAIL";;		 
		"Diameter Peer Connect on ES"*)
                set_messages "diameterPeerConnectionFailure" "10009" "$SEVERITY" "Diameter Peer Connect on ES" "Diameter Peer Connect on ES : $MESSAGE_DETAIL";;	  
		"Service Provisioning Subsystem Connection on ES"*)
                set_messages "serviceProvisioningSubsystemFailure" "10010" "$SEVERITY" "Service Provisioning Subsystem Connection on ES" "Service Provisioning Subsystem Connection on ES : $MESSAGE_DETAIL";;		
        "check_role_subs"*)
                set_messages "roleSubsFailure" "10012" "CRITICAL" "Subscription service failed" "CDP ES subscription service not reachable. $MESSAGE_DETAIL";;
        "check_role_auth"*)
                set_messages "roleAuthFailure" "10013" "CRITICAL" "Authentication service failed" "CDP ES authentication service not reachable. $MESSAGE_DETAIL";;
        *"check_role_eswebsheet"*)
                set_messages "roleWebsFailure" "10014" "CRITICAL" "Websheet service failed" "CDP ES websheet service not reachable. $MESSAGE_DETAIL";;
        "check_role_push"*)
                set_messages "rolePushFailure" "10015" "CRITICAL" "Push service failed" "CDP ES push notification service not reachable. $MESSAGE_DETAIL";;
        		"check_lb_capacity"*) #CRITICAL or OK
                set_messages "lbLimitReachedTrap" "10016" "$SEVERITY" "CDP ES loadbalancer capacity overload" "One specific CDP ES loadbalancer has reached its capacity limit";;
        "cdrloghandler"*) #WARNING (### We could later drop a Cancel alarm, if needed)
                set_messages "fileUploadTrap" "10017" "WARNING" "CDP ES file upload to external host failed" "CDP ES could not upload a file to external host (CDR event log): $MESSAGE_DETAIL";;
        "pmfilehandler"*) #WARNING (### We could later drop a Cancel alarm, if needed)
                set_messages "fileUploadTrap" "10018" "WARNING" "CDP ES file upload to external host failed" "CDP ES could not upload a file to external host (PM files to Netact): $MESSAGE_DETAIL";;		


        "CDP License"*)

                set_messages "licenseIssueTrap" "10019" "$SEVERITY" "License Issue" "License Issue: $MESSAGE_DETAIL"
                ;;


        
        "CDP License"*)

                set_messages "licenseIssueTrap" "10019" "$SEVERITY" "License Issue" "License Issue: $MESSAGE_DETAIL"
                ;;

        "CDP SCE console"*|"CDP UI console"*)
		set_messages "webappUnreachableTrap" "10004" "$SEVERITY" "CDP application is unreachable" "app $MESSAGE_DESC is unreachable: $MESSAGE_DETAIL"
		;;
        "GoldenGate Checkpoint delay"*)
                set_messages "geoDBReplicationLagTrap" "15005" "$SEVERITY" "GoldenGate Checkpoint delay" "GoldenGate Checkpoint delay: $MESSAGE_DETAIL"
		;;
        "GoldenGate Replication lag"*)

                set_messages "geoDBReplicationLagTrap" "15006" "$SEVERITY" "GoldenGate Replication lag" "GoldenGate Replication lag: $MESSAGE_DETAIL"
		;;
		"GoldenGate Replication Difference"*)
			
                set_messages "geoDBReplicationLagTrap" "15006" "$SEVERITY" "GoldenGate Replication lag" "GoldenGate Replication lag: $MESSAGE_DETAIL"
		;;
        "GoldenGate errors"*)
                set_messages "geoDBReplicationErrorTrap" "15007" "$SEVERITY" "GoldenGate Replication error" "GoldenGate Replication error: $MESSAGE_DETAIL"
		;;
        "GoldenGate processes check"*)
                set_messages "geoDBReplicationProcessesIssueTrap" "15008" "$SEVERITY" "GoldenGate Replication processes issue" "GoldenGate Replication processes issue: $MESSAGE_DETAIL"
		;;
        "CDP HealthCheck"*)
                set_messages "hostUnreachableTrap" "15001" "$SEVERITY" "Health check application is unreachable" "Health check application unreachable : $MESSAGE_DETAIL"
		;;
        "CDP GEO State Check"*)
                set_messages "geoSiteStateChangeTrap" "15004" "$SEVERITY" "Site state change" "Site state change : $MESSAGE_DETAIL"
		;;
		"Websheet Failure"*)
				set_messages "websheetTrap" "15019" "$SEVERITY" "Websheet not reachable" "Websheet not reachable : $MESSAGE_DETAIL"
		;;				
        *)
                exit 2;;
esac

if [ -z "${ALARM_NUM}" ]; then exit 1; fi

arr=$(echo $NETACT | /usr/bin/tr ";" "\n")
for x in $arr
do
    snmptrap -v2c -c public $x "" ${TRAP_TYPE} ${ALARM_NUM} ${NOTIF_ID} ${A_SEVERITY} $MIB::cdpAlarmText s "${ALARM_TEXT}" $MIB::cdpAdditionalText1 s "${ALARM_ADD}" ${ALARM_TIME}
done


