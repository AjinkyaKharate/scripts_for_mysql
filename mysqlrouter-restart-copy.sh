#!/bin/bash

user='admin'
passwd=$( openssl enc -base64 -d < /opt/mysqlrouter/password_admin.dat )
hostname=$(hostname)
server_ip=$(hostname -i|grep 10)
# Email function to send alerts
send_email(){
        subject=$1
        message=$2
        ( echo open smtp-ip 25
        sleep 8
        echo helo smtp-ip
        echo mail from: aca@gja.com
        sleep 2
        echo rcpt to: xyz@abc.com
        #sleep 2
        echo data
        sleep 2
        echo subject: $1
        echo
        echo
        sleep 2
        echo $2
        sleep 5
        echo .
        sleep 5
        echo quit ) | telnet
}

if [ -e /data/mysqlrouter/ ]; then
        if [ -e /data/mysqlrouter/mysqlrouter.log ]; then
                echo "" > /dev/null
        else
                touch /data/mysqlrouter/mysqlrouter_remote.log
        fi
else
        mkdir /data/mysqlrouter
        touch /data/mysqlrouter/mysqlrouter_remote.log
fi

#checking login
mysqlsh -u $user -p$passwd -S /opt/mysqlrouter/mysql.sock --sql -e "select 1;"
if [ $? -eq 0 ]; then
    echo "$(date "+%y-%m-%d %H:%M:%S") Login successfull. MySQL Router is healthy."
else
#when login gets fail 
    echo "$(date "+%y-%m-%d %H:%M:%S") Failed to login. Checking with mysqlrouter service and mysql.sock file..."
#checking if mysqlrouter service is running and mysql.sock is present
    if systemctl is-active --quiet mysqlrouter.service && [ -e /opt/mysqlrouter/mysql.sock ]; then
        echo "$(date "+%y-%m-%d %H:%M:%S") MySQL Router service i up and running and mysql.sock file is present. Again trying to login..."
        mysqlsh -u $user -p$passwd -S /opt/mysqlrouter/mysql.sock --sql -e "select 1;"
        if [ $? -eq 0]; then
            echo "$(date "+%y-%m-%d %H:%M:%S") Login successfull. MySQL router is healthy."
        else
            echo "$(date "+%y-%m-%d %H:%M:%S") Trying login for 2nd time. Still not able to login. Need to restart mysqlrouter service. This can also be innodb cluster issue."
            systemctl stop mysqlrouter
            systemctl start mysqlrouter
            sleep 2
            if systemctl is-active --quiet mysqlrouter.service && [ -e /opt/mysqlrouter/mysql.sock ]; then
                echo "$(date "+%y-%m-%d %H:%M:%S") Router service restart successfully and mysql.sock is also present. Checkin login again..."
                mysqlsh -u $user -p$passwd -S /opt/mysqlrouter/mysql.sock --sql -e "select 1;"
                if [ $? -eq 0]; then
                    echo "$(date "+%y-%m-%d %H:%M:%S") Login successfull. MySQL router is healthy."
                else
                    echo "$(date "+%y-%m-%d %H:%M:%S") tried login after stop and start of mysqlrouter but still not able to login. This can also be innodb cluster issue."
                    echo "$(date "+%y-%m-%d %H:%M:%S") sending mail..."
                    send_email "MySQL Router Issue" "Tried login and restarting mysqlrouter service but still not able to login. Check server-ip=$server_ip and server-name=$hostname. "
                fi
            else
                a=0
                while [ $a -lt 3]
                do
                    systemctl stop mysqlrouter
                    systemctl start mysqlrouter
                    sleep 2
                    if [ systemctl is-active --quiet mysqlrouter.service ] && [ -e /opt/mysqlrouter/mysql.sock ]; then
                        echo "$(date "+%y-%m-%d %H:%M:%S") Service started but required multiple restart. mysql.sock is also present."
                    else
                        a=$(($a+1))
                    fi
                done
                echo "$(date "+%y-%m-%d %H:%M:%S") tried restarting 3 times but service was not starting or mysql.sock file was not present."
                echo "$(date "+%y-%m-%d %H:%M:%S") sending mail..."
                send_email "MySQL Router Issue" "Tried restarting script for multiple time but either service was not starting or mysql.sock file was not present. Check server-ip=$server_ip and server-name=$hostname"
            fi
        fi
    else
        systemctl stop mysqlrouter
        systemctl start mysqlrouter
        sleep 2
        if systemctl is-active --quiet mysqlrouter.service && [ -e /opt/mysqlrouter/mysql.sock ]; then
            echo "$(date "+%y-%m-%d %H:%M:%S") MySQL router service was stopped. Now, service started and mysql.sock file is also present. Now checking with login..
            mysqlsh -u $user -p$passwd -S /opt/mysqlrouter/mysql.sock --sql -e "select 1";"
            if [ $? -eq 0 ]; then
                echo "$(date "+%y-%m-%d %H:%M:%S")  Login successfull. MySQL Router is healthy."
            else
                echo "$(date "+%y-%m-%d %H:%M:%S") Login failed. Tried stopping and starting mysqlrouter service. Sending mail.."
                send_email "MySQL Router Issue" "MySQL Router service is down. Please check server-ip=$server_ip and server_name=$hostname."
            fi
        else
            echo "$(date "+%y-%m-%d %H:%M:%S") Service was already stopped. Tried stopping and starting. Service is $(systemctl is-active mysqlrouter.service) or mysql.sock $([ -e /opt/mysqlrouter/mysql.sock ] && echo "File exists" || echo "File does not exist") in the required directory."
            echo "$(date "+%y-%m-%d %H:%M:%S") Sending mail...."
            send_email "MySQL Router Issue" "Service was already down. MySQL router service is $(systemctl is-active mysqlrouter.service) or mysql.sock $([ -e /opt/mysqlrouter/mysql.sock ] && echo "File exists" || echo "File does not exist")."
        fi
    fi
fi

