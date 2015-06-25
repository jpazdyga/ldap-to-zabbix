#!/bin/bash

defaultldaptree=`echo "OU=Groups,OU=UNIX,DC=root,DC=com"`
call="/usr/bin/mysql -N -uroot -ptestpasswd zabbix -e"
tmpfile="/tmp/ldap_to_zabbix_userlist.tmp"
arg1="$1"
arg2="$2"
arg3="$3"
viewersgrpid="11"
adminsgrpid="7"

log()
{
        logger "ldap_to_zabbix: $1"
}

userinsert()
{
        lastuserid=`$call "select * from users order by userid desc limit 1;" | awk '{print $1}'`
        nextuserid=`expr $lastuserid + 1`
        $call "insert into users values ('$nextuserid','$alias','$forename','$surname','5fce1b3e34b520afeffb37ce08c7cd66','','0','0','en_GB','30','$role','default','0','','','50');"
        case $? in
                0)
			# maybe use tee?
                        log "User \"$alias\" has been added."
                        echo "User \"$alias\" has been added."
                ;;
                *)
                        log "Error occured during adding process."
                        echo "Error occured during adding process."
                ;;
        esac
        groupinsert
}

userdelete()
{
        $call "delete from users where alias='$alias';"
        case $? in
                0)
                        log "User \"$alias\" has been removed."
                        echo "User \"$alias\" has been removed."
                ;;
                *)
                        log "Error occured during removal process."
                        echo "Error occured during removal process."
                ;;
        esac
}

groupinsert()
{
        lastusrgrpid=`$call "select * from users_groups order by id desc limit 1;" | awk '{print $1}'`
        nextusrgrpid=`expr $lastusrgrpid + 1`
        $call "insert into users_groups values ('$nextusrgrpid','$grpid','$nextuserid');"
}

permlevelupdate()
{
        $call "update users set users.type='$role' where alias='$alias';"
        $call "update users_groups set users_groups.usrgrpid='$grpid' where userid='$curusrid';"
         case $? in
                0)
                        log "User \"$alias\" has been changed."
                        echo "User \"$alias\" has been changed."
                ;;
                *)
                        log "Error occured during user update process."
                        echo "Error occured during user update process."
                ;;
        esac
}

permlevelset()
{
        case $arg3 in
                admins)
                        grpid="$adminsgrpid"
                        role="3"
                ;;
                viewers)
                        grpid="$viewersgrpid"
                        role="2"
                ;;
                *)
                        echo -e "Third argument should indicate access level for specified group's members.\nPlease use either \"viewers\" or \"admins\"\n"
                        exit 1
                ;;
        esac
}

permlevelchk()
{
        curlvl=`echo $getusrinfo | awk -F ',' '{print $1}'`
        curusrid=`echo $getusrinfo | awk -F ',' '{print $2}'`
        permlevelupdate
}

check()
{
        getusrinfo=`$call "select type,userid from users where alias='$alias'" | awk '{print $1","$2}'`
        case $1 in
                0)
                        permlevelset
                        if [ -z "$getusrinfo" ];
                        then
                                userinsert
                        else
                                log "User \"$alias\" already exists. Skipping."
                                echo "User \"$alias\" already exists. Skipping."
                                permlevelchk
                                return 1
                        fi
                ;;
                1)
                        if [ -z "$getusrinfo" ];
                        then
                                log "User \"$alias\" already deleted. Skipping."
                                echo "User \"$alias\" already deleted. Skipping."
                                return 1
                        else
                                userdelete
                        fi
                ;;
                *)
                        log "Error passing an argument to function check()"
                        echo "Error passing an argument to function \"check()\""
                        exit 1
                ;;
        esac
}

helpmsg()
{
        echo -e "
        Please use:
        \"$0 insert CN\" to add members of this group
        or
        \"$0 delete|remove CN\" to remove those members.
        Third argument should indicate access level for specified group's members.
        Please use either \"viewers\" or \"admins\"
        Thank you!
        \n
        Note:
        CN means ldap's CN group common name in ldap tree. For this example: 
        CN=zabbixadmins,OU=Groups,OU=UNIX,DC=ROOT,DC=com
        you should replace 'CN' from usage message with 'zabbixadmins'.
        Whole 'OU=Groups,OU=EMEA,DC=ROOT,DC=com' is an assumption and it's just added to the group's common name.\n
        Working examples:
        1. search LDAP for members of CN=ftlabs,OU=Groups,OU=EMEA,DC=ROOT,DC=com and add it's members as regular, read-only users to Zabbix:
        ldap_to_zabbix.sh insert ftlabs viewers

        2. search LDAP for members of CN=ftlabops,OU=Groups,OU=EMEA,DC=ROOT,DC=com and make them Zabbix Administrators: (note they were added to Zabbix with previous step, you are actually updating)
        ldap_to_zabbix.sh insert ftlabops admins

        3. Remove all Administrators:
        ldap_to_zabbix.sh delete ftlabops

        4. and remove users:
        ldap_to_zabbix.sh delete ftlabs

        TODO:
        Lots of things, let's just test this for now.

        --
        \xc2\xa9 Jakub Pazdyga, FTLabs

        "
}

usagemsg()
{
        echo -e "Usage: $0 [insert|remove] [AD group] [viewers|admins]
                   - insert     insert group into assigned Zabbix group
                   - remove     remove group from assigned Zabbix group\n
                Please use --help for detailed usage\n"
}

case "$arg1" in
        "")
                echo -e "\nNo argument passed.\n"
                usagemsg
                exit 1
        ;;
        "--help")
                helpmsg
                exit 0
        ;;
esac

ldapgroup="$arg2"
users=`/usr/bin/ldapsearch -o nettimeout=3 -wtestpasswd -D 'CN=ldapuser,OU=Service Accounts,OU=Service Admins,DC=root,DC=com' -H ldaps://ldap.root.com -x -b "CN=$ldapgroup,$defaultldaptree" -LLL member | grep -vw "dn:" | awk -F "=" '{print $2}' | awk -F 
',' '{print $1,$2}' | sed 's/\\\  /./g' | cut -d" " -f1 | grep '\.' | awk -F '.' '{print $2"."$1}'`

log "Automated ldap account synchronization with Zabbix is being executed (for $ldapgroup):"

for j in `echo "$users"`;
do
        username="$j"
        alias=`/usr/bin/ldapsearch -o nettimeout=3 -wtestpasswd -D 'CN=ldapuser,OU=Service Accounts,OU=Service Admins,DC=root,DC=com' -H ldaps://ldap.root.com -x -b DC=root,DC=com -LLL -s sub '(sAMAccountName='"$username"')' sAMAccountName | grep -w 
"sAMAccountName:" | awk '{print $2}'`
        forename=`echo $alias | awk -F '.' '{print $1}'`
        surname=`echo $alias | awk -F '.' '{print $2" "$3}' | sed 's/ *$//g'`
        case $arg1 in
                insert)
                        check 0
                ;;
                remove)
                        check 1
                ;;
                *)
                        echo -e "\nWrong argument passed to the script.\n"
                        usagemsg
                        exit 1
                ;;
        esac
done

log "Automated ldap account synchronization with Zabbix finished."
