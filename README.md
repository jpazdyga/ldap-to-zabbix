# ldap-to-zabbix

<b>Working examples:</b>
<br />
        1. search LDAP for members of CN=ftlabs,OU=Groups,OU=EMEA,DC=ROOT,DC=com and add it's members as regular, read-only users to Zabbix:<br />
        ldap_to_zabbix.sh insert ftlabs viewers<br />
<br />
        2. search LDAP for members of CN=ftlabops,OU=Groups,OU=EMEA,DC=ROOT,DC=com and make them Zabbix Administrators: (note they were added to Zabbix with previous step, you are actually updating)<br />
        ldap_to_zabbix.sh insert ftlabops admins<br />
<br />
        3. Remove all Administrators:<br />
        ldap_to_zabbix.sh delete ftlabops<br />
<br />
        4. and remove users:<br />
        ldap_to_zabbix.sh delete ftlabs<br />
<br />
        TODO:<br />
        Lots of things, let's just test this for now.<br />
