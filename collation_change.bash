#!/bin/bash
##This script can change the collation of databases.
read -sp "Enter your password for admin: " pswd
home_dir=$(echo ~mysql)
conf_path=$(ps -eo comm,pcpu,cmd --sort -pcpu | grep mysql |head -1 |awk '{ print $4 }'|cut -d"=" -f2)
base_dir=$(cat $conf_path|grep basedir|sed -n '1p'|cut -d"=" -f2)
socket_path=$(cat $conf_path|grep 'mysql.sock'| sed -n '1p'|cut -d"=" -f2)

usage() {
        echo "usage: $(basename $0) [option]"
        echo "option=all: Perform conversion of collation of all-databases"
        echo "option=database: Perform conversion of specific database"
        echo "option=help: show this help"
}

all_databases() {
                db=$($base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "select distinct TABLE_SCHEMA from information_schema.COLUMNS where TABLE_SCHEMA NOT IN ('mysql', 'performance_schema', 'sys', 'information_schema', 'mysql_innodb_cluster_metadata');")
                declare -a myarray=($db)
                touch $home_dir/trash.txt
                for x in "${myarray[@]}"
                do
#						$base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "use $x;"
                        echo "$x database selected."
                        $base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "select concat('ALTER TABLE',' ', TABLE_SCHEMA,'.',TABLE_Name, ' MODIFY ',COLUMN_NAME, ' ' , COLUMN_TYPE, ' CHARACTER SET utf8mb4;') command from information_schema.COLUMNS WHERE TABLE_SCHEMA = '$x' and CHARACTER_SET_NAME != 'utf8mb4' and COLLATION_NAME not like '%utf8mb4%';" > /tmp/output.sql
                        sed '1d' /tmp/output.sql > $home_dir/trash.txt
                        sed -i 'USE $x' /tmp/output.sql
						echo "Setting foreign keys to OFF."
                        sed -i '1i SET FOREIGN_KEY_CHECKS=0;' /tmp/output.sql
                        echo "Foreign keys set to OFF."
                        echo "Running alter commands."
                        $base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "source /tmp/output.sql"
                        echo "All alter commands completed."
                        echo "Setting foreign keys to ON."
                        sed -i '$i SET FOREIGN_KEY_CHECKS=1;' /tmp/output.sql
                        echo "Foreign keys set to ON."
                        check=$($base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "SELECT TABLE_SCHEMA, TABLE_NAME ,COLUMN_NAME, COLLATION_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = '$x' and COLLATION_NAME!='NULL' and COLLATION_NAME not like '%utf8mb4%' and CHARACTER_SET_NAME != 'utf8mb4';" )
                        check_val=$( echo $check | wc -c )
                        if [ "$check_val" == "1" ]
                        then
                                echo "Coloumn wise collation has changed."
                                echo "Now starting table wise collation..."
                                $base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "select concat('ALTER TABLE',' ', TABLE_SCHEMA,'.',TABLE_Name, ' convert to character set utf8mb4 collate utf8mb4_0900_ai_ci;') command from INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '$x' and TABLE_COLLATION!='utf8mb4_0900_ai_ci';" > /tmp/output_table.sql
                                sed '1d' /tmp/output_table.sql > /tmp/trash1.txt
                                $base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "source /tmp/output_table.sql"
                                check1=$($base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "select TABLE_SCHEMA,TABLE_NAME,TABLE_TYPE,TABLE_COLLATION from INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '$x' and TABLE_COLLATION !='utf8mb4' and TABLE_COLLATION not like '%utf8mb4%';")
                                check1_val=$(echo $check1 |wc -c)
                                if [ "$check1_val" == "1" ]
                                then
                                        echo "Table wise collation has completed."
                                        echo "Now starting Database wise collation..."
                                        $base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "alter database $x CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"
                                        check2=$($base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "show create database $x;") > /tmp/trash2.txt
                                        check2_val=$(cat /tmp/trash2.txt | grep -w "utf8mb3" | wc -c )
                                        if [ "$check2_val" == "0" ]
                                        then
                                            echo "Database wise collation has changed."
                                        else
                                            echo "Database wise collation has failed."
                                        fi
                                else
                                    echo "Table wise collation has failed."
                                fi
                        else
                                "Something happened. Please start the script again."
                        fi
                        truncate -s 0 /tmp/output.sql $home_dir/trash
                done
#               echo "All Databases collation has changed."
}
value="$1"
database(){

#               value=0
                db=$($base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "select distinct TABLE_SCHEMA from information_schema.COLUMNS where TABLE_SCHEMA NOT IN ('mysql', 'performance_schema', 'sys', 'information_schema', 'mysql_innodb_cluster_metadata');")
                declare -a myarray=($db)
                touch $home_dir/trash.txt $home_dir/trash1.txt
#               for i in "${myarray[@]}"
#               do
#                       value=value+1
#                       echo "checking for $i"
                if [[ " ${myarray[*]} " =~ "$value" ]]
                then
                        echo "Database is present."
#						$base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "use $value;"
                        $base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "select concat('ALTER TABLE',' ', TABLE_SCHEMA,'.',TABLE_Name, ' MODIFY ',COLUMN_NAME, ' ' , COLUMN_TYPE, ' CHARACTER SET utf8mb4;') command from information_schema.COLUMNS WHERE TABLE_SCHEMA = '$value' and CHARACTER_SET_NAME!='utf8mb4' and COLLATION_NAME not like '%utf8mb4%';" > /tmp/output.sql
                        sed '1d' /tmp/output.sql > $home_dir/trash.txt
						sed -i 'USE $value' /tmp/output.sql
                        echo "Setting foreign keys to OFF."
                        sed -i '1i SET FOREIGN_KEY_CHECKS=0;' /tmp/output.sql
                        echo "Foreign keys set to OFF."
                        echo "Running alter commands."
                        $base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "source /tmp/output.sql"
                        echo "All alter commands completed."
                        echo "Setting foreign keys to ON."
                        sed -i '$i SET FOREIGN_KEY_CHECKS=1;' /tmp/output.sql
                        echo "Foreign keys set to ON."
                        check=$($base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "SELECT TABLE_SCHEMA, TABLE_NAME ,COLUMN_NAME, COLLATION_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = '$i' and COLLATION_NAME!='NULL' and COLLATION_NAME not like '%utf8mb4%' and CHARACTER_SET_NAME != 'utf8mb4';" )
                        check_val=$( echo $check | wc -c )
                    if [ "$check_val" == "1" ]
                    then
                        echo "$value Coloumn wise collation has changed."
                                echo "Now starting table wise collation...."
                                $base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "select concat('ALTER TABLE',' ', TABLE_SCHEMA,'.',TABLE_Name, ' convert to character set utf8mb4 collate utf8mb4_0900_ai_ci;') command from INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '$value' and TABLE_COLLATION!='utf8mb4_0900_ai_ci';" > /tmp/output_table.sql
                                sed '1d' /tmp/output_table.sql > /tmp/trash1.txt
                                $base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "source /tmp/output_table.sql"
                                check1=$($base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "select TABLE_SCHEMA,TABLE_NAME,TABLE_TYPE,TABLE_COLLATION from INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '$value' and TABLE_COLLATION !='utf8mb4' and TABLE_COLLATION not like '%utf8mb4%';")
                                check1_val=$(echo $check1 |wc -c)
                                if [ "$check1_val" == "1" ]
                                then
                                        echo "Table wise collation has completed."
                                        echo "Now starting Database wise collation..."
                                        $base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "alter database $value CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"
                                        check2=$($base_dir/bin/mysql -u admin -p$pswd -S $socket_path -Bse "show create database $value;")>/tmp/trash2.txt
                                        check2_val=$(cat /tmp/trash2.txt | grep -w "utf8mb3" | wc -c )
                                        if [ "$check2_val" == "0" ]
                                        then
                                            echo "Database wise collation has changed."
                                        else
                                            echo "Database wise collation has failed."
                                        fi
                                else
                                        echo "Table wise collation has failed."
                                fi
                    else
                        echo "Something happened. Please start the script again."
                    fi
                        truncate -s 0 /tmp/output.sql $home_dir/trash
                else
                        echo "${value} is not present."
                fi
#               done
}

if [ $# -eq 0 ]
then
usage
exit 1
fi

case $1 in
    "all")
        all_databases
        ;;
#    "database")
#    database
#       ;;
    "help")
        usage
        break
        ;;
    *) database;;
esac
