#!/bin/bash
# ERROR CODE:
## 0 success
## 1 wrong user
## 2 resources are occupied
## 3 operation fail

# make the repository for apps, set appropriate rights. for example:
#mkdir -p /var/apps/
#chown root:root /var/apps/
#chmod 2775 /var/apps/ 

# Please change these variables when deploy new apps:
CATALINA_OPTS='"-server -Xms512M -Xmx1024M -XX:PermSize=256M -XX:MaxPermSize=512M"'
APP_NAME="[app1|app2|app3|<newAPP>]"

# Do not change these variables:
ACTION="[start|stop|restart|[deploy <username>]]" 
CATALINA_HOME="/opt/tomcat/apache-tomcat-7.0.35"
CATALINA_BASE_PRE="/var/apps/tomcat-"

fun_usage ()
{
 echo "Usage:"
 echo " `basename $0` <APP_NAME> <ACTION>"
 echo
 echo " APP_NAME:"
 echo "  $APP_NAME"
 echo
 echo " ACTION:"
 echo "  $ACTION"
 echo
 exit 0
}

fun_start ()
{
 PORTS=(`awk 'BEGIN { ORS=" " }
 /<!--/,/-->/ {next} 
 /<Server/,/>/ {
  for (i=1;i<=NF;i++)
   if($i ~ /port="*"/) {
     gsub(/"/,"",$i)
     port_num=substr($i,6)
     print port_num
   }
 }
 /<Connector/,/>/ {
  for (i=1;i<=NF;i++)
   if($i ~ /port="*"/) {
    gsub(/"/,"",$i)
    port_num=substr($i,6)
    print port_num
   }
 }' $CATALINA_BASE/conf/server.xml`)

 for i in ${PORTS[@]}
  do
   ss -tunlp | egrep ":$i[[:blank:]]" &>/dev/null
   if [ $? -eq 0 ]
    then {
     echo "ERROR: Port \"$i\" is on listening, please check first!"
     exit 2
    }
   fi
 done
  if [ -s $PID_FILE ]
   then
    PID_NUM=`cat $PID_FILE`
    ps aux | awk '{print $2}' | egrep  "^${PID_NUM}$"
    if [ $? -eq 0 ]
     then
      echo "ERROR: Process ID \"${PID_NUM}\"  exists, please check first!"
      exit 2
     else {
      rm -rf $PID_FILE
      if [ $? -ne 0 ]
       then
        echo "ERROR: Can't delete file \"$PID_FILE\", please delete it manually!"
        exit 3
      fi 
     } 
    fi
  fi
 $CATALINA_HOME/bin/catalina.sh start
}

fun_stop ()
{
 $CATALINA_HOME/bin/catalina.sh stop -force
 sleep 3
 if [ -s $PID_FILE ]
  then
  {
   echo "WARN: Continue to stop..."
   kill `cat $PID_FILE` && rm -rf $PID_FILE
   if [ $? -eq 0 ]
    then
     echo "Completed!"
   else 
    echo "ERROR: please stop it manually"
   fi
  }
 fi
}

fun_restart ()
{
 fun_stop
 fun_start
}

fun_deploy ()
{
  mkdir -p ${CATALINA_BASE}/{bin,conf,lib,logs,temp,webapps,work}
  cp $CATALINA_HOME/bin/{setenv.sh,tomcat-juli.jar} ${CATALINA_BASE}/bin/
  cp $CATALINA_HOME/conf/* ${CATALINA_BASE}/conf/
  echo "CATALINA_OPTS=${CATALINA_OPTS}" >> ${CATALINA_BASE}/bin/setenv.sh
  chown -R ${OWNER_NAME}:${OWNER_NAME} ${CATALINA_BASE}
  sed -i 's/\(APP_NAME=".*\)\(<newAPP>]"$\)/\1'"${NEW_APP}"'|\2/' $0
  echo "Success! New App: \"${NEW_APP}\" deployed in ${CATALINA_BASE}"
  echo "Important!!! Remember to modify the listen port in file: ${CATALINA_BASE}/conf/server.xml"
}

if [ -z "$1" ] || [ -z "$2" ]
 then
  fun_usage
 else
  if [ `echo $APP_NAME | egrep "\[$1\||\|$1\||\|$1\]"` ]
   then
    {
     CATALINA_BASE="${CATALINA_BASE_PRE}""$1"
     OWNER_NAME=$(ls -ld $CATALINA_BASE | cut -d' ' -f3) 
     OWNER_UID=$(ls -lnd $CATALINA_BASE | cut -d' ' -f3)
     PID_FILE=$CATALINA_BASE/tomcat.pid
     export CATALINA_BASE
      if [ $UID -ne $OWNER_UID ]
       then
        echo "WARN: Please run this script with the user \"$OWNER_NAME\"."
        exit 1
      fi
     case "$2" in
      start) fun_start
            ;;
      stop) fun_stop
           ;;
      restart) fun_restart
              ;;
      *) fun_usage
         ;;
     esac
    }
   elif [ $2 == "deploy" ] && [ -n "$3" ]
    then 
      CATALINA_BASE="${CATALINA_BASE_PRE}""$1"
      OWNER_NAME="$3"
      NEW_APP="$1"
      id $OWNER_NAME &>/dev/null
      if [ $? -eq 0 ]
         then
            case $UID in
             0)
              fun_deploy
              ;;
            *)
              echo "WARN: Please deploy new app with the user \"root\"."
              ;;
            esac
      else
         echo "Please create the app owner first"
      fi
   else
     fun_usage
  fi
fi
