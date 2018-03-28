#!/bin/bash
# **************************************************************************************
# *                                                                                    *
# *  DXP demo VM installation script.                                                  *
# *  Written by : Gerben Kranenborg                                                    *
# *  Date : October 20, 2017                                                           *
# *                                                                                    *
# **************************************************************************************

Init()
{
# **************************************************************************************
# *                                                                                    *
# * This function will initialize this script, by setting variables etc.               *
# *                                                                                    *
# **************************************************************************************

	VERSION="14.2"
	INSTALL_FILE_DIR=`pwd`
	CONFIG_FILE=$INSTALL_FILE_DIR/dxp.config
	SOFTWARE=$INSTALL_FILE_DIR/software
	REA_DIR=$INSTALL_FILE_DIR/rea
	WEB_DIR=$INSTALL_FILE_DIR/web
	FCLASSES=$INSTALL_FILE_DIR/flowable-classes
	BAL_DIR=$INSTALL_FILE_DIR/bal-jars
	MISC_DIR=$INSTALL_FILE_DIR/misc
	APPVERSIONFILE=/var/www/html/assets/appversions.json
	APPINSTALLFILE=/var/www/html/assets/appinstall.json
	
	if [ ! -f $CONFIG_FILE ]
	then
		Screen_output 0 " The installation files cannot be found in the current directory. Please restart the installation in the correct directory !!"
		Abort_install
	else
		source $CONFIG_FILE
		mkdir -p $INSTALL_LOG_DIR >$ILOG 2>&1
	fi
}

Install_user_check()
{
# **************************************************************************************
# *                                                                                    *
# *  This function checks to make sure the 'root' user is performing the installation. *
# *                                                                                    *
# **************************************************************************************
	if [ $(id -u) != "0" ]
	then
		Screen_output 0 "You must run this installation script as user root. Please login again as user root and restart the installation !!"
		Abort_install
	fi
}

Welcome()
{
# **************************************************************************************
# *                                                                                    *
# *  This function shows the welcome screen at the (re)start of each installation.     *
# *                                                                                    *
# **************************************************************************************
	echo "** Welcome **" >> $ERROR
	clear
	echo ""
	echo " Welcome to the DXP VM installation script. (v.$VERSION)"
	echo ""
	echo " This script will configure the O.S. and install several other (optional) components"
	echo ""
	echo " *********************************************************************************************"
	echo ""
	echo " This installation has been started as a SILENT installation."
	echo " The installation script will not prompt you for any input, until the end of the installation,"
	echo " or if an error occurs during the installation process."
	echo ""
	echo " WARNING : Shortly after the start of the installation, the VM / server will reboot."
	echo " Once this is done, log in again as root and go to $INSTALL_FILE_DIR and"
	echo " re-start the installation by typing   ./dxp-install.sh"
	echo ""
	echo " *********************************************************************************************"
	Continue
	case "$APPLICATION" in
	IBPM)
		if [ "$COMBOINSTALL" = "true" ]
		then
			 BANNER="IBPM + Flowable (DXP Enterprise +)"
		else 
			BANNER="Interstage BPM (DXP Enterprise)"
		fi
	;;
	FLOWABLE)
		BANNER="Flowable (DXP Community)"
	;;
	REA)
		BANNER="REA (DXP Lite)"
	;;
	esac
	clear
	echo " *********************************************************************************************"
	echo ""
	echo -e " The installation of \033[33;7m$BANNER \033[0m has been started."
	echo ""
	echo " *********************************************************************************************"
	echo ""
	echo -n " $BANNER will be installed, is this correct (y/n) ? [y] : "
	read INPUT
	if [ "$INPUT" = "n" ]
	then
		echo ""
		echo -n " Which application do you want to install ? IBPM (I), Flowable (F), REA (R) or IBPM + Flowable (C) ? : "
		read INPUT
		OLDAPP=$APPLICATION
		OLDCOMBO=$COMBOINSTALL
		case "$INPUT" in
			I)
				APPLICATION="IBPM"
				COMBOINSTALL="false"
			;;
			F)
				APPLICATION="FLOWABLE"
				COMBOINSTALL="false"
			;;
			R)
				APPLICATION="REA"
				COMBOINSTALL="false"
			;;
			C)
				APPLICATION="IBPM"
				COMBOINSTALL="true"
			;;
			*)
				clear
				echo ""
				echo " Your selection ( $INPUT ) is incorrect. Please try again ...."
				sleep 3
				Welcome
		esac
		sed -i -e "s/APPLICATION=\"$OLDAPP\"/APPLICATION=\"$APPLICATION\"/g" $CONFIG_FILE
		sed -i -e "s/COMBOINSTALL=\"$OLDCOMBO\"/COMBOINSTALL=\"$COMBOINSTALL\"/g" $CONFIG_FILE
	fi
	echo ""
	echo -n " The new VM version is set to be : $VMVERSION. Is this correct (y/n) ? [y] : "
	read INPUT
	echo ""
	if [ "$INPUT" = "n" ]
	then
		echo -n " What would you like the version to be ? : "
		read INPUT
		sed -i -e "s/VMVERSION=\"$VMVERSION\"/VMVERSION=\"$INPUT\"/g" $CONFIG_FILE
		VMVERSION=$INPUT
		echo ""
	fi
	if [ "$APPLICATION" = "IBPM" ]
	then
		if [ "$ALFRESCO" = "true" ]
		then
			ALFQUESTION="Alfresco will be installed."
		else
			ALFQUESTION="Alfresco will NOT be installed."
		fi
		echo ""
		echo -n " $ALFQUESTION Is this correct (y/n) ? [y] : "
		read INPUT
		echo ""
		if [ "$INPUT" = "n" ]
		then
			if [ "$ALFRESCO" = "true" ]
			then
				sed -i -e "s/ALFRESCO=\"true\"/ALFRESCO=\"false\"/g" $CONFIG_FILE
				ALFRESCO="false"
			else
				sed -i -e "s/ALFRESCO=\"false\"/ALFRESCO=\"true\"/g" $CONFIG_FILE
				ALFRESCO="true"
			fi
			echo ""
		fi
	fi
	echo -n " The location for all software to be installed is : $TARGET_DIR. Is this correct (y/n) ? [y] : "
	read INPUT
	if [ "$INPUT" = "n" ]
	then
		echo ""
		echo -n " In which directory would you like the software to be installed ? : "
		read INPUT
		if [ ! -d $INPUT ]
		then
			mkdir -p $INPUT 2>$ILOG
			ret=$?
			if [ $ret -ne 0 ]
			then
				echo ""
				echo " The directory $INPUT could not be created ....."
				Continue
			fi
		fi
		sed -i -e "s#TARGET_DIR=\"$TARGET_DIR\"#TARGET_DIR=\"$INPUT\"#g" $CONFIG_FILE
		TARGET_DIR=$INPUT
	fi
	INSTALL_LOG_DIR=$TARGET_DIR/logs
	mkdir $INSTALL_LOG_DIR
	ERROR=$INSTALL_LOG_DIR/install-error.log
	ILOG=$INSTALL_LOG_DIR/ilog.log
	echo "" >> $ERROR
	date >> $ERROR
	echo "" >> $ERROR
	touch $INSTALL_LOG_DIR/welcome.log
}

Resource_check()
{
# **************************************************************************************
# *                                                                                    *
# * This function will check the server for certain resources (Memory / CPU), prior    *
# * to the start of the installation.                                                  *
# *                                                                                    *
# **************************************************************************************
	echo "*** Checking system resources ***" >>$ERROR
	TOTALMEM=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
	if [ "$TOTALMEM" -lt "7000000" ]
	then
		Screen_output 0 "The Server requires at least 8GB of Memory for the installation !!"
		Abort_install
	fi
	TOTALCPU=`grep processor /proc/cpuinfo | wc -l`
	if [ "$TOTALCPU" -lt "2" ]
	then
		Screen_output 0 "The Server requires at least 2 CPU's for the installation !!"
		Abort_install
	fi	
}

Check_install_files()
{
# **************************************************************************************
# *                                                                                    *
# * This function will check for the existance of all required installation files.     *
# * If any of them cannot be found, the installation will be aborted.                  *
# *                                                                                    *
# **************************************************************************************
	echo "*** Checking installation files ***" >>$ERROR
	
# **** General checks ****	

	Check_file $SOFTWARE/jdk-8u$VJDK8-linux-x64.rpm JDK8
	Check_file $WEB_DIR/web.zip TMP
	Check_file $WEB_DIR/scripts/systemstatus TMP
	Check_file $INSTALL_FILE_DIR/options/chat/app.js TMP
	Check_file $MISC_DIR/README.txt README
	
# **** Checks if application is not Flowable or if only Flowable ****
	
	if [ "$APPLICATION" != "FLOWABLE" ]
	then
		Check_file $SOFTWARE/elasticsearch-$VELK.rpm ELASTIC
		Check_file $SOFTWARE/elasticsearch-head-master.zip ESHEAD
	else
		Check_file $SOFTWARE/apache-tomcat-$VAPACHE.tar.gz APACHE
		Check_file $SOFTWARE/node-v$VNODE-linux-x64.tar.xz NODE
		Check_file $SOFTWARE/postgresql96-$VPGDG-1PGDG.rhel7.x86_64.rpm PGDG
		Check_file $SOFTWARE/postgresql96-libs-$VPGDG-1PGDG.rhel7.x86_64.rpm PGDGLIB
		Check_file $SOFTWARE/postgresql96-server-$VPGDG-1PGDG.rhel7.x86_64.rpm PGDGSERVER
		Check_file $SOFTWARE/flowable-$VFLOWABLE.zip FLOWABLE
		Check_file $FCLASSES/db.properties TMP
		Check_file $FCLASSES/flowable-admin.xml TMP
		Check_file $FCLASSES/flowable-idm.xml TMP
		Check_file $FCLASSES/flowable-modeler.xml TMP
		Check_file $FCLASSES/flowable-task.xml TMP
		Check_file $MISC_DIR/flowable-rest.xml TMP
		Check_file $MISC_DIR/initflowable.sql TMP
	fi
	
# **** Checks if application is IBPM ****	
	
	if [ "$APPLICATION" = "IBPM" ]
	then
		Check_file $SOFTWARE/jboss-eap-$VJBOSS.zip JBOSS
		Check_file $SOFTWARE/I-BPM$VIBPM-EnterpriseEdition-CD_IMAGE*.zip IBPM
		Check_file $SOFTWARE/Patch/BZ-1358913.zip JBOSSBZ
		Check_file $BAL_DIR/BPMActionLibrary.jar TMP
		Check_file $BAL_DIR/twitter4j-core-4.0.4.jar TMP
		PNUM=1
		while [ $PNUM -lt 10 ]
		do
			Check_file $SOFTWARE/Patch/jboss-eap-6/jboss-eap-6.4.$PNUM.CP.zip TMP
			PNUM=`expr $PNUM + 1`
		done
		if [ "$ALFRESCO" = "true" ]
		then
			Check_file $SOFTWARE/alfresco-community-installer-$VALFRESCO-linux-x64.bin ALFRESCO
			Check_file $MISC_DIR/alfresco.start TMP
		fi
		if [ "$IBPMDB" = "postgresas" ]
		then
			Check_file $SOFTWARE/ppasmeta-$VPPAS-linux-x64.tar.gz PPAS
		else
			Check_file $SOFTWARE/oracle-xe-$VORACLE-1.0.x86_64.rpm.zip ORACLE
			Check_file $MISC_DIR/smtphost.sql SMTPHOST
		fi
	fi
	
	# **** Checks if application is REA ****
	
	if [ "$APPLICATION" = "REA" ]
	then
		Check_file $REA_DIR/default.conf TMP
		Check_file $REA_DIR/nginx.conf TMP
		Check_file $REA_DIR/mybackup.tar TMP
		Check_file $REA_DIR/rea.zip TMP
	fi
}

Change_os_settings()
{
# **************************************************************************************
# *                                                                                    *
# * This function makes the required changes to the OS settings, such as network,      *
# * fire-wall, SElinux etc. changes.                                                   *
# *                                                                                    *
# **************************************************************************************
	if [ ! -f $INSTALL_LOG_DIR/colorchange.log ]
	then
		sed -i -e 's/COLOR tty/COLOR none/g' /etc/DIR_COLORS 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "The modification of the file /etc/DIR_COLORS failed."
			echo " Errorcode : $ret"
			Continue
		else
			touch $INSTALL_LOG_DIR/colorchange.log
		fi
	fi
	if [ ! -f $INSTALL_LOG_DIR/rootchange.log ]
	then
		sed -i -e 's/#PermitRootLogin/PermitRootLogin/g' /etc/ssh/sshd_config 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "The modification of the file /etc/ssh/sshd_config failed."
			echo " Errorcode : $ret"
			Continue
		else
			touch $INSTALL_LOG_DIR/rootchange.log
		fi
	fi
	if [ ! -f $INSTALL_LOG_DIR/selinuxchange.log ]
	then
		sed -i -e 's/\=enforcing/\=disabled/g' /etc/sysconfig/selinux 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "The modification of the file /etc/sysconfig/selinux failed."
			echo " Errorcode : $ret"
			Continue
		else
			touch $INSTALL_LOG_DIR/selinuxchange.log
		fi
	fi
	if systemctl | grep firewalld >$ILOG
	then
		if [ ! -f $INSTALL_LOG_DIR/firewallchange.log ]
		then
			systemctl stop firewalld >$ILOG 2>>$ERROR
			ret=$?
			if [ $ret -ne 0 ]
			then
				Screen_output 0 "The fire-wall could not be stopped. This can lead to failures and access issues later on."
				echo " Errorcode : $ret"
				Continue
			fi
			systemctl disable firewalld >$ILOG 2>>$ERROR
			ret=$?
			if [ $ret -ne 0 ]
			then
				Screen_output 0 "The fire-wall could not be disabled. This can lead to failures and access issues later on."
				echo " Errorcode : $ret"
				Continue
			else
				touch $INSTALL_LOG_DIR/firewallchange.log
			fi
		fi
	fi
	if [ ! -f $INSTALL_LOG_DIR/networkchange.log ]
	then
		if [ "$DEMOVM" = "true" ]
		then
			case "$APPLICATION" in
				IBPM)
					if [ "$COMBOINSTALL" = "true" ]
					then
						NEWHOSTNAME="$IBPMFLOWHOSTNAME"
					else
						NEWHOSTNAME="$IBPMHOSTNAME"
					fi
				;;
				FLOWABLE)
					NEWHOSTNAME="$FLOWHOSTNAME"
				;;
				REA)
					NEWHOSTNAME="$REAHOSTNAME"
				;;
			esac
			hostnamectl set-hostname $NEWHOSTNAME> $ILOG 2>>$ERROR
			ret=$?
			if [ $ret -ne 0 ]
			then
				Screen_output 0 "The VM's hostname could not be changed to $NEWHOSTNAME"
				echo " Errorcode : $ret"
				Abort_install
			fi
		else
			NEWHOSTNAME=`hostname`
		fi
		HOSTENTRY=`grep $NEWHOSTNAME /etc/hosts`
		if [ "$HOSTENTRY" = "" ]
		then
			IPADDRESS=`ip addr | grep "inet" | grep -ve "127.0.0.1" | grep -ve "inet6" | awk '{print $2}' | cut -f1 -d"/"`
			echo "$IPADDRESS	$NEWHOSTNAME" >> /etc/hosts 2>>$ERROR
		fi
		if [ ! -d $TARGET_DIR/utilities ]
		then
			mkdir $TARGET_DIR/utilities 2>>$ERROR
		fi
		echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
		echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
		if [ -f /etc/sysconfig/network-scripts/ifcfg-eno* ]
		then
			NETWORKFILE=`ls /etc/sysconfig/network-scripts/ifcfg-eno*`
		else
			NETWORKFILE=`ls /etc/sysconfig/network-scripts/ifcfg-ens*`
		fi
		sed -i -e 's/IPV6INIT="yes"/IPV6INIT="no"/g' $NETWORKFILE 2>>$ERROR 
		systemctl restart network >$ILOG 2>>$ERROR
		touch $INSTALL_LOG_DIR/networkchange.log
	fi
	if [ -f /usr/lib/systemd/system/poweroff.target ]
	then
		sed -i -e "s/30min/1min/g" /usr/lib/systemd/system/poweroff.target
	fi
	if [ -f /usr/lib/systemd/system/reboot.target ]
	then
		sed -i -e "s/30min/1min/g" /usr/lib/systemd/system/reboot.target
	fi
	touch $INSTALL_LOG_DIR/oschange.log
}

Install_scripts()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install the Welcome screen and the ipchange script.             *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing Service scripts ***" >>$ERROR
	
# **** Create / Install script to handle IP address changes ****
	if [ "$DEMOVM" = "true" ]
	then
		echo "#!/bin/sh" > /etc/rc.d/init.d/ipchange
		echo "#" >> /etc/rc.d/init.d/ipchange
		echo "# chkconfig: 3 70 05" >> /etc/rc.d/init.d/ipchange
		echo "#" >> /etc/rc.d/init.d/ipchange
		echo "PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin" >> /etc/rc.d/init.d/ipchange
		echo "NEWVMIP=\`ip addr | grep \"inet\" | grep -ve \"127.0.0.1\" | grep -ve \"inet6\" | awk '{print \$2}' | cut -f1 -d\"/\"\`" >> /etc/rc.d/init.d/ipchange
		echo "HOSTNAME=\`hostname\`" >> /etc/rc.d/init.d/ipchange
		echo "OLDVMIP=\`grep \$HOSTNAME /etc/hosts | cut -f1 -d'	'\`" >> /etc/rc.d/init.d/ipchange
		echo "sed -i \"/\$HOSTNAME/d\" /etc/hosts 2>/dev/null" >> /etc/rc.d/init.d/ipchange
		echo "sed -i \"/\$NEWVMIP/d\" /etc/hosts 2>/dev/null" >> /etc/rc.d/init.d/ipchange
		echo "sed -i \"/\$OLDVMIP/d\" /etc/hosts 2>/dev/null" >> /etc/rc.d/init.d/ipchange
		echo "echo \"\$NEWVMIP	\$HOSTNAME\" >> /etc/hosts" >> /etc/rc.d/init.d/ipchange
		chmod 755 /etc/rc.d/init.d/ipchange 2>>$ERROR
		chkconfig --add ipchange 2>>$ERROR
		chkconfig --level 3 ipchange on 2>>$ERROR
	fi
	
# **** Installation of VM welcome screen scripts ****

	case "$APPLICATION" in
		IBPM)
			if [ "$COMBOINSTALL" = "true" ]
			then
				APPNAME="(Enterprise+)"
			else
				APPNAME="(Enterprise) "
			fi
		;;
		FLOWABLE)
			APPNAME="(Community)  "
		;;
		REA)
			APPNAME="( Lite )     "
		;;
	esac
	echo "#!/bin/bash" > /etc/rc.d/rc.local
	echo "echo \" \"  > /etc/issue" >> /etc/rc.d/rc.local
	echo "" >> /etc/rc.d/rc.local
	echo "VMURL=\`ip addr | grep \"inet\" | grep -ve \"127.0.0.1\" | grep -ve \"inet6\" | awk '{print \$2}' | cut -f1 -d\"/\"\`" >> /etc/rc.d/rc.local
	echo "DUMMY=\"                         \"" >> /etc/rc.d/rc.local
	echo "HOSTNAME=\`hostname\`" >> /etc/rc.d/rc.local
	echo "" >> /etc/rc.d/rc.local
	echo "echo    \" ****************************************************************************** \"      >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo    \" |                                                                            | \"      >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo    \" |                        Fujitsu DXP ${APPNAME} demo VM                   | \"      >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo    \" |                                                                            | \"      >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo -n \" |                         Hostname : \"                                       >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo    \"\${HOSTNAME}\${DUMMY:0:\`expr 31 - \${#HOSTNAME}\`}         | \"                         >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo -n \" |                       IP address : \"                                       >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo    \"\${VMURL}\${DUMMY:0:\`expr 31 - \${#VMURL}\`}         | \"                                    >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo    \" |                                                                            | \"      >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo    \" |                          LoginID : root                                    | \"      >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo    \" |                         Password : Fujitsu1                                | \"      >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo    \" |----------------------------------------------------------------------------| \"      >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo    \" |                                                                            | \"      >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo -n \" |                              URL : \"                                       >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo    \"http://\${HOSTNAME}\${DUMMY:0:\`expr 31 - \${#HOSTNAME}\`}  | \"                             >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo    \" |                                                                            | \"      >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo    \" ****************************************************************************** \"      >> /etc/issue" >> /etc/rc.d/rc.local
	echo "echo    \"\"                                                                                      >> /etc/issue" >> /etc/rc.d/rc.local
	chmod 755 /etc/rc.d/rc.local 2>>$ERROR
	systemctl enable rc-local.service 2>>$ERROR
	> /etc/issue 2>>$ERROR
	touch $INSTALL_LOG_DIR/scriptinstall.log
	/etc/rc.d/init.d/ipchange >$ILOG 2>>$ERROR
}

Reset_rootpw()
{
# **************************************************************************************
# *                                                                                    *
# * This function will reset the root password to the default.                         *
# *                                                                                    *
# **************************************************************************************
	echo "*** Changing root password ***" >>$ERROR
	RESETROOTPW=`grep "RESETROOTPW:" $CONFIG_FILE | cut -f2 -d":"` 
	if [ "$RESETROOTPW" = "true" ]
	then
		passwd root <<RESETPW >$ILOG 2>&1
Fujitsu1
Fujitsu1
RESETPW
	fi
	touch $INSTALL_LOG_DIR/rootpwreset.log
}

Check_file()
{
# **************************************************************************************
# *                                                                                    *
# * This function will test the existence of a file.                                   *
# *                                                                                    *
# **************************************************************************************
	if [ ! -f $1 ]
	then
		Screen_output 0 "The $1 installation file cannot be found in. The installation will be aborted !!"
		echo "File $1 missing." >> $ERROR
		Abort_install
		exit 0
	else
		eval $2FILE="$1"
	fi
}

Check_tools()
{
# **************************************************************************************
# *                                                                                    *
# *  This function will check to make sure the various tools required for the          *
# *  installation are available.                                                       *
# *                                                                                    *
# **************************************************************************************
	echo "*** Checking tools ***" >>$ERROR
	if ! type unzip >$ILOG 2>&1
	then
		yum -y install unzip telnet telnet-server netstat httpd git open-vm-tools >$ILOG 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "Tool updates failed to get installed !!"
			Continue
		else
			if [ -f /etc/securetty ]
			then
				rm -rf /etc/securetty
			fi
			echo "#! /bin/bash" > /etc/rc.d/init.d/telnet
			echo "#" >> /etc/rc.d/init.d/telnet
			echo "# telnet	Start and Stop telnet" >> /etc/rc.d/init.d/telnet
			echo "#" >> /etc/rc.d/init.d/telnet
			echo "# chkconfig: 3 85 04" >> /etc/rc.d/init.d/telnet
			echo "#" >> /etc/rc.d/init.d/telnet
			echo "PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin" >> /etc/rc.d/init.d/telnet
			echo "case \"\$1\" in" >> /etc/rc.d/init.d/telnet
			echo "start)" >> /etc/rc.d/init.d/telnet
			echo "	systemctl enable telnet.socket" >> /etc/rc.d/init.d/telnet
			echo "	systemctl start telnet.socket" >> /etc/rc.d/init.d/telnet
			echo ";;" >> /etc/rc.d/init.d/telnet
			echo "esac" >> /etc/rc.d/init.d/telnet
			chmod 755 /etc/rc.d/init.d/telnet 2>>$ERROR
			chkconfig --add telnet 2>>$ERROR
			chkconfig --level 3 telnet on 2>>$ERROR
			/usr/bin/vmware-toolbox-cmd timesync enable >$ILOG 2>>$ERROR
		fi
	fi
	if ! type bzip2 >$ILOG 2>&1
	then
		yum -y install bzip2 >$ILOG 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "bzip2 failed to get installed !!"
			Continue
		fi
	fi
	if [ "$IBPMDB" = "oracle" -a "$APPLICATION" = "IBPM" ]
	then
		yum -y install bc >$ILOG 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "bc failed to get installed !!"
			Continue
		fi
	fi
	if [ "$APPLICATION" = "REA" ]
	then
		yum -y install epel-release >$ILOG 2>>$ERROR
		yum -y install nginx >$ILOG 2>>$ERROR
	fi
	yum -y update >$ILOG 2>&1
	ret=$?
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "CentOS failed to get updated !!"
		Continue
	fi
}

Install_jdk()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install JDK in the default directory.                           *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing JDK ***" >>$ERROR
	rpm -i $JDK8FILE >$ILOG 2>>$ERROR
	ret=$?
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "The installation of JDK1.8 failed."
		echo ""
		echo " Errorcode : $ret"
		Abort_install
	else
		touch $INSTALL_LOG_DIR/jdkinstalled.log
	fi
}

Install_oracle()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install and configure Oracle XE.                                *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing Oracle ***" >>$ERROR
	if [ ! -f $INSTALL_LOG_DIR/oraclezip.log ]
	then
		unzip  -o $ORACLEFILE -d $INSTALL_LOG_DIR >$ILOG 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "The Oracle installation file failed to unzip !!"
			echo " Errorcode : $ret"
			echo ""
			Abort_install
		else
			>$INSTALL_LOG_DIR/oraclezip.log
		fi
	fi
	if [ ! -f $INSTALL_LOG_DIR/oracledbinst.log ]
	then
		rpm -i $INSTALL_LOG_DIR/Disk1/oracle-xe*64.rpm >$ILOG 2>&1
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "Oracle failed to install completely !!"
			echo " Errorcode : $ret"
			echo ""
			Abort_install
		else
			>$INSTALL_LOG_DIR/oracledbinst.log
		fi
	fi
	if [ ! -f $INSTALL_LOG_DIR/oracleconfigured.log ]
	then
		/etc/init.d/oracle-xe configure << ORACCONF >$ILOG 2>&1
$ORACLEHTTP
$ORACLELIST
$ORACLEPWD
$ORACLEPWD
$ORACLESTART
ORACCONF
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "The Oracle DB configuration failed to complete !!"
			echo " Errorcode : $ret"
			echo ""
			Abort_install
		else
			>$INSTALL_LOG_DIR/oracleconfigured.log
		fi
	fi
	echo ". /u01/app/oracle/product/11.2.0/xe/bin/oracle_env.sh" >> /root/.bashrc 2>>$ERROR
	touch $INSTALL_LOG_DIR/oracleinstalled.log
}

Install_postgresas()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install and initialize Postgres.                                *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing Postgres AS***" >>$ERROR
	gunzip -c $PPASFILE >$INSTALL_LOG_DIR/ppasmeta.tar 2>>$ERROR
	if [ ! -f $INSTALL_LOG_DIR/ppastar.log ]
	then
		tar xvf $INSTALL_LOG_DIR/ppasmeta.tar -C $INSTALL_LOG_DIR >$ILOG 2>>$ERROR
	fi
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "The PostgresAS file failed to unzip !!"
		echo " Errorcode : $ret"
		echo ""
		Abort_install
	else
		>$INSTALL_LOG_DIR/ppastar.log
		rm -rf $INSTALL_LOG_DIR/ppasmeta.tar
	fi
	$INSTALL_LOG_DIR/ppasmeta*x64/ppas*run <<ENDPOSTGRES >$ILOG 2>>$ERROR
1












y
gerben7164@hotmail.com
Kawasaki7
$TARGET_DIR/edb
y
y
y
n
y
n
n
y
n
n
y
$TARGET_DIR/edb/9.5AS/data
$TARGET_DIR/edb/9.5AS/data/pg_xlog
1
Fujitsu1
Fujitsu1
5444
1
n
2
1
y
y

y
ENDPOSTGRES
	ret=$?
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "The Postgres installation failed to complete !!"
		echo " Errorcode : $ret"
		echo ""
		Abort_install
	else
		rm -rf $INSTALL_LOG_DIR/ppasmeta*x64
		source $TARGET_DIR/edb/9.5AS/pgplus_env.sh >$ILOG 2>>$ERROR
		sed -i -e 's/#work_mem = 4MB/work_mem = 20MB/g' $TARGET_DIR/edb/9.5AS/data/postgresql.conf 2>>$ERROR
		chmod 755 $TARGET_DIR/edb/connectors/jdbc/*jar >$ILOG 2>>$ERROR
		POSTGRESJAR=`ls $TARGET_DIR/edb/connectors/jdbc/edb-*17.jar`
		sed -i -e "s/127\.0\.0\.1\/32/0\.0\.0\.0\/0/g" $TARGET_DIR/edb/9.5AS/data/pg_hba.conf
		echo "export PGDATA=$TARGET_DIR/edb/9.5AS/data" >>/root/.bashrc
		su enterprisedb -c "$TARGET_DIR/edb/9.5AS/bin/pg_ctl restart" >$ILOG 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "The Postgres DB server failed to start !!"
			echo " Errorcode : $ret"
			echo ""
			Abort_install
		else
			sleep 20
			touch $INSTALL_LOG_DIR/postgresasinstalled.log
		fi
	fi
}

Install_jboss()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install JBoss6.4                                                *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing JBoss ***" >>$ERROR
	if [ ! -f $INSTALL_LOG_DIR/jbossinstalled.log ]
	then
		unzip  -o $JBOSSFILE -d $TARGET_DIR >$ILOG 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "The JBoss 6.4 file failed to unzip !!"
			echo " Errorcode : $ret"
			echo ""
			Abort_install
		else
			chmod 755 $TARGET_DIR/jboss-eap-6.4/bin/*.sh >$ILOG 2>>$ERROR
			touch $INSTALL_LOG_DIR/jbossinstalled.log
		fi
	fi
	if [ ! -f $INSTALL_LOG_DIR/jbossconfigured.log ]
	then
		JBOSSFAIL="false"
		sed -i -e '/<servers>/,/<\/servers>/{//!d}' $TARGET_DIR/jboss-eap-6.4/domain/configuration/host.xml 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			JBOSSFAIL="true"
		fi
		sed -i -s 's/security-realm=\"ApplicationRealm\"//g' $TARGET_DIR/jboss-eap-6.4/domain/configuration/domain.xml 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			JBOSSFAIL="true"
		fi
		sed -i -e 's/230\.0\.0\.4/230\.0\.0\.1/g' $TARGET_DIR/jboss-eap-6.4/domain/configuration/domain.xml 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			JBOSSFAIL="true"
		fi
		sed -i -e 's/231\.7\.7\.7/231\.7\.7\.1/g' $TARGET_DIR/jboss-eap-6.4/domain/configuration/domain.xml 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			JBOSSFAIL="true"
		fi
		sed -i -e "s/127\.0\.0\.1/$NEWHOSTNAME/g" $TARGET_DIR/jboss-eap-6.4/domain/configuration/host.xml 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			JBOSSFAIL=true
		fi
		if [ "$JBOSSFAIL" = "true" ]
		then
			Screen_output 0 "The configuration of the JBoss host.xml or domain.xml file failed !!"
			echo ""
			Abort_install
		else
			touch $INSTALL_LOG_DIR/jbossconfigured.log
		fi
	fi
	touch $INSTALL_LOG_DIR/jboss.log
}

Jboss_startup()
{
# **************************************************************************************
# *                                                                                    *
# * This function will setup the scripts to automatically startup JBoss.               *
# *                                                                                    *
# **************************************************************************************
	echo "*** Starting JBoss ***" >>$ERROR
	mkdir $TARGET_DIR/utilities/log 2>>$ERROR
	echo "#! /bin/bash" > /etc/rc.d/init.d/jbossibpm
	echo "#" >> /etc/rc.d/init.d/jbossibpm
	echo "# jbossibpm	Start and Stop JBoss / Interstage BPM" >> /etc/rc.d/init.d/jbossibpm
	echo "#" >> /etc/rc.d/init.d/jbossibpm
	echo "# chkconfig: 3 85 04" >> /etc/rc.d/init.d/jbossibpm
	echo "#" >> /etc/rc.d/init.d/jbossibpm
	echo "PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin" >> /etc/rc.d/init.d/jbossibpm
	echo "case \"\$1\" in" >> /etc/rc.d/init.d/jbossibpm
	echo "start)" >> /etc/rc.d/init.d/jbossibpm
	echo "	export LAUNCH_JBOSS_IN_BACKGROUND=true" >> /etc/rc.d/init.d/jbossibpm
	echo "	$TARGET_DIR/jboss-eap-6.4/bin/domain.sh >$TARGET_DIR/utilities/log/jbossibpmstart &" >> /etc/rc.d/init.d/jbossibpm
	echo "	touch /var/lock/subsys/jbossibpm" >> /etc/rc.d/init.d/jbossibpm
	echo "	echo \$! >$TARGET_DIR/utilities/log/jbosspid" >> /etc/rc.d/init.d/jbossibpm
	echo ";;" >> /etc/rc.d/init.d/jbossibpm
	echo "stop)" >> /etc/rc.d/init.d/jbossibpm
	echo "	echo \"Stopping JBoss / Interstage BPM\"" >> /etc/rc.d/init.d/jbossibpm
	echo "	echo \"Stop\" >$TARGET_DIR/utilities/log/jbossstop" >> /etc/rc.d/init.d/jbossibpm
	echo "	kill \`cat $TARGET_DIR/utilities/log/jbosspid\`" >> /etc/rc.d/init.d/jbossibpm
	echo "	rm -rf /var/lock/subsys/jbossibpm" >> /etc/rc.d/init.d/jbossibpm
	echo ";;" >> /etc/rc.d/init.d/jbossibpm
	echo "esac" >> /etc/rc.d/init.d/jbossibpm
	chmod 755 /etc/rc.d/init.d/jbossibpm 2>>$ERROR
	chkconfig --add jbossibpm 2>>$ERROR
	chkconfig --level 3 jbossibpm on 2>>$ERROR
	sed -i -e "s/localhost/$NEWHOSTNAME/g" $TARGET_DIR/jboss-eap-6.4/bin/jboss-cli.xml 2>>$ERROR
	service jbossibpm start >$ILOG 2>>$ERROR
	touch $INSTALL_LOG_DIR/jbossstart.log
	sleep 5
	IPADDRESS=`ip addr | grep "inet" | grep -ve "127.0.0.1" | grep -ve "inet6" | awk '{print $2}' | cut -f1 -d"/"` 2>>$ERROR
	JBOSSPRC=`ps -ef|grep jboss|wc -l`
	if [ $JBOSSPRC -lt 2 ]
	then
		echo " JBoss does not appear to be running. Please check this first before continuing."
		echo ""
		Continue
	fi
}

Jdbc_config()
{
# **************************************************************************************
# *                                                                                    *
# * This function will configure the JBoss JDBC settings.                              *
# *                                                                                    *
# **************************************************************************************
	echo "*** Configuring JBoss ***" >>$ERROR
	if [ "$IBPMDB" = "oracle" ]
	then
		. /u01/app/oracle/product/11.2.0/xe/bin/oracle_env.sh 2>>$ERROR
	fi
	if [ ! -f $INSTALL_LOG_DIR/jbossmodule.log ]
	then
		case "$IBPMDB" in
			oracle)
				echo "module add --name=com.oracle.jdbc --resources=$ORACLE_HOME/jdbc/lib/ojdbc6.jar --dependencies=javax.api,javax.transaction.api">$INSTALL_LOG_DIR/cliscript 2>>$ERROR
			;;
			postgresas)
				POSTGRESJAR=`ls $TARGET_DIR/edb/connectors/jdbc/edb-*17.jar`
				echo "module add --name=com.postgres.jdbc --resources=$POSTGRESJAR --dependencies=javax.api,javax.transaction.api">$INSTALL_LOG_DIR/cliscript 2>>$ERROR
			;;
		esac
		echo "quit">>$INSTALL_LOG_DIR/cliscript 2>>$ERROR
		$TARGET_DIR/jboss-eap-6.4/bin/jboss-cli.sh --file=$INSTALL_LOG_DIR/cliscript 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			clear
			echo ""
			echo " The JDBC / JBoss configuration failed."
			echo ""
			echo " The errorcode is : $ret"
			echo ""
			Abort_install
		else
			rm -rf $INSTALL_LOG_DIR/cliscript
			touch $INSTALL_LOG_DIR/jbossmodule.log
		fi
	fi
	$TARGET_DIR/jboss-eap-6.4/bin/add-user.sh -s $JBOSSUSER $JBOSSPWD > $ILOG 2>>$ERROR
	ret=$?
	if [ $ret -ne 0 ]
	then
		clear
		echo ""
		echo " The JBoss admin user did not get added."
		echo ""
		echo " The errorcode is : $ret"
		echo ""
		Continue
	fi
	touch $INSTALL_LOG_DIR/jdbcconfig.log
}

Ibpm_engine()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install the I-BPM engine directory.                             *
# *                                                                                    *
# **************************************************************************************
	echo "*** Unzipping I-BPM engine directory ***" >>$ERROR
	unzip  -o $IBPMFILE 'engine/*' -d $TARGET_DIR >$ILOG 2>>$ERROR
	ret=$?
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "The Interstage BPM engine folder did not get installed !!"
		echo ""
		echo " The errorcode is : $ret"
		echo ""
		if [ ! -d $TARGET_DIR/engine ]
		then
			echo " The folder $TARGET_DIR/engine does not exist. Please check the $IBPMFILE to make sure it contains an engine folder."
		fi
		Abort_install
	else
		chmod 755 $TARGET_DIR/engine/server/setup.sh 2>>$ERROR
		touch $INSTALL_LOG_DIR/engineconfig.log
	fi
	
}

Setup_config()
{
# **************************************************************************************
# *                                                                                    *
# * This function will modify the setup.config file for IBPM prior to the installation.*
# *                                                                                    *
# **************************************************************************************
	echo "*** Modifying I-BPM config files ***" >>$ERROR
	sed -i -e 's/appserver_selected\=/appserver_selected\=JBoss/g' $TARGET_DIR/engine/server/setup.config 2>>$ERROR
	case "$IBPMDB" in
		oracle)
			sed -i -e 's/database_selected\=/database_selected\=Oracle/g' $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e 's/jdbc_module_name\=/jdbc_module_name\=com.oracle.jdbc/g' $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e "s/db_ibpm_password\=/db_ibpm_password\=$ORACLEPWD/g" $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e "s/db_port\=/db_port\=$ORACLELIST/g" $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e "s|db_jdbc_library_path\=|db_jdbc_library_path\=$ORACLE_HOME\/jdbc\/lib\/ojdbc6.jar|g" $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e "s|db_database_home\=|db_database_home\=$ORACLE_HOME|g" $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e "s/db_admin_password\=/db_admin_password\=$ORACLEPWD/g" $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e 's/db_data_file_location\=/db_data_file_location\=\/u01\/app\/oracle\/oradata\/XE/g' $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e 's/db_instance_name\=ORCL/db_instance_name\=XE/g' $TARGET_DIR/engine/server/setup.config 2>>$ERROR
		;;
		postgresas)
			sed -i -e 's/database_selected\=/database_selected\=EDBPostgres/g' $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e 's/jdbc_module_name\=/jdbc_module_name\=com.postgres.jdbc/g' $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e "s/db_ibpm_password\=/db_ibpm_password\=Fujitsu1/g" $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e "s/db_port\=/db_port\=5444/g" $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e "s|db_jdbc_library_path\=|db_jdbc_library_path\=$POSTGRESJAR|g" $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e "s/db_admin_user_name\=sa/db_admin_user_name\=enterprisedb/g" $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e "s/db_admin_password\=/db_admin_password\=Fujitsu1/g" $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e "s|db_data_file_location\=|db_data_file_location\=$TARGET_DIR\/edb\/9.5AS\/data|g" $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e 's/database_creation_selection\=0/database_creation_selection\=1/g' $TARGET_DIR/engine/server/setup.config 2>>$ERROR
			echo "db_name=ibpmdb" >>$TARGET_DIR/engine/server/setup.config 2>>$ERROR
			echo "postgres_home=$TARGET_DIR/edb/9.5AS" >>$TARGET_DIR/engine/server/setup.config 2>>$ERROR
			sed -i -e "s/^PASSWORD\=/PASSWORD\=Fujitsu1/g" $TARGET_DIR/engine/server/deployment/dbsetup/postgresql/config.sh 2>>$ERROR
			sed -i -e "s|POSTGRES_HOME\=|POSTGRES_HOME\=$TARGET_DIR\/edb\/9.5AS|g" $TARGET_DIR/engine/server/deployment/dbsetup/postgresql/config.sh 2>>$ERROR
			sed -i -e "s/DB_ADMIN_USER\=/DB_ADMIN_USER\=enterprisedb/g" $TARGET_DIR/engine/server/deployment/dbsetup/postgresql/config.sh 2>>$ERROR
			sed -i -e "s/DB_ADMIN_PASSWORD\=/DB_ADMIN_PASSWORD\=Fujitsu1/g" $TARGET_DIR/engine/server/deployment/dbsetup/postgresql/config.sh 2>>$ERROR
			sed -i -e "s/PORT\=/PORT\=5444/g" $TARGET_DIR/engine/server/deployment/dbsetup/postgresql/config.sh 2>>$ERROR
		;;
	esac
	sed -i -e "s|appserver_home\=|appserver_home\=$TARGET_DIR\/jboss-eap-6.4|g" $TARGET_DIR/engine/server/setup.config 2>>$ERROR
	sed -i -e "s/db_host\=localhost/db_host\=$NEWHOSTNAME/g" $TARGET_DIR/engine/server/setup.config 2>>$ERROR
	sed -i -e 's/super_user\=ibpm_server1/super_user\=admin/g' $TARGET_DIR/engine/server/setup.config 2>>$ERROR
	sed -i -e 's/super_user_password\=/super_user_password\=Fujitsu1/g' $TARGET_DIR/engine/server/setup.config 2>>$ERROR
	sed -i -e 's/LDAPAccessUserID\=ibpm_server1/LDAPAccessUserID\=admin/g' $TARGET_DIR/engine/server/setup.config 2>>$ERROR
	sed -i -e 's/LDAPAccessUserPassword\=/LDAPAccessUserPassword\=Fujitsu1/g' $TARGET_DIR/engine/server/setup.config 2>>$ERROR
	sed -i -e "s/localhost/$NEWHOSTNAME/g" $TARGET_DIR/engine/server/deployment/bin/setIBPMEnv.sh 2>>$ERROR
	touch $INSTALL_LOG_DIR/setupconfig.log
}

Install_ibpm()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install Interstage BPM.                                         *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing I-BPM ***" >>$ERROR
	JAVAPATH=`ls /usr/java/jdk*/LIC*` 2>>$ERROR
	export JAVA_HOME=`dirname $JAVAPATH` 2>>$ERROR
	case "$IBPMDB" in
		oracle)
			. /u01/app/oracle/product/11.2.0/xe/bin/oracle_env.sh 2>>$ERROR
			echo "INBOUND_CONNECT_TIMEOUT_XE=0" >> $ORACLE_HOME/network/admin/listener.ora 2>>$ERROR
			echo "DIRECT_HANDOFF_TTC_XE=OFF" >> $ORACLE_HOME/network/admin/listener.ora 2>>$ERROR
			echo "SQLNET.INBOUND_CONNECT_TIMEOUT=0" > $ORACLE_HOME/network/admin/sqlnet.ora 2>>$ERROR
			lsnrctl reload >$ILOG 2>&1
		;;
		postgresas)
			if [ ! -f $INSTALL_LOG_DIR/postgresdbinstalled.log ]
			then
				cd $TARGET_DIR/engine/server/deployment/dbsetup/postgresql
				chmod 755 *.sh >$ILOG 2>>$ERROR
				export PGDATA="$TARGET_DIR/edb/9.5AS/data"
				./dbsetup.sh >$ILOG 2>>$ERROR
				ret=$?
				if [ $ret -ne 0 ]
				then
					Screen_output 0 "The Interstage BPM Postgres DB installation failed !!"
					echo ""
					echo " The errorcode is : $ret"
					echo ""
					echo " Also check the log file in $INSTALL_FILE_DIR/logs"
					echo ""
					Abort_install
				else
					touch $INSTALL_LOG_DIR/postgresdbinstalled.log
				fi
				cd $INSTALL_FILE_DIR
			fi
		;;
	esac
	sleep 20
	$TARGET_DIR/engine/server/setup.sh -configFilePath $TARGET_DIR/engine/server/setup.config >$ILOG 2>>$ERROR
	ret=$?
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "The Interstage BPM installion failed !!"
		echo ""
		echo " The errorcode is : $ret"
		echo ""
		echo " Also check the log file in $TARGET_DIR/engine/server/deployment/logs"
		echo ""
		Abort_install
	else
		case "$IBPMDB" in
			oracle)
				sed -i -e "s/jdbc:oracle:thin:@localhost:1521:XE/jdbc:oracle:thin:@$NEWHOSTNAME:1521:XE/g" $TARGET_DIR/jboss-eap-6.4/domain/configuration/domain.xml 2>>$ERROR
			;;
		esac
		Change_smtp
		touch $INSTALL_LOG_DIR/ibpminstalled.log
		case "$IBPMDB" in
			oracle)
				rm -rf $ORACLE_HOME/network/admin/sqlnet.ora
			;;
		esac
	fi
}

Install_bpmaction()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install the BPM Action Library files.                           *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing BPMAction ***" >>$ERROR
	cp $INSTALL_FILE_DIR/bal-jars/*jar $TARGET_DIR/engine/server/instance/default/lib/ext 2>>$ERROR
	cp $INSTALL_FILE_DIR/bal-jars/*txt $TARGET_DIR/engine/server/instance/default/resources 2>>$ERROR
	cp $INSTALL_FILE_DIR/bal-jars/*bar $TARGET_DIR/engine/server/instance/default/lib/ext 2>>$ERROR
	cp $INSTALL_FILE_DIR/bal-jars/*properties $TARGET_DIR/engine/server/instance/default/lib/ext 2>>$ERROR
	touch $INSTALL_LOG_DIR/bpmaction.log
}

Install_postgres()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install and initialize Postgres.                                *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing Postgres ***" >>$ERROR
	rpm -i $PGDGLIBFILE>$ILOG 2>>$ERROR
	ret=$?
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "The Postgres Libs installation failed to complete !!"
		echo " Errorcode : $ret"
		echo ""
		Abort_install
	else
		rpm -i $PGDGFILE>$ILOG 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "The Postgres installation failed to complete !!"
			echo " Errorcode : $ret"
			echo ""
			Abort_install
		else
			mkdir -p $TARGET_DIR/postgres/data >$ILOG 2>>$ERROR
			rpm -i $PGDGSERVERFILE>$ILOG 2>>$ERROR
			ret=$?
			if [ $ret -ne 0 ]
			then
				Screen_output 0 "The Postgres Server installation failed to complete !!"
				echo " Errorcode : $ret"
				echo ""
				Abort_install
			else
				chown postgres:postgres $TARGET_DIR/postgres/data >$ILOG 2>>$ERROR
				su postgres -c '/usr/pgsql-9.6/bin/initdb -D /opt/postgres/data' >$ILOG 2>>$ERROR
				sed -i -e "s/127\.0\.0\.1\/32/0\.0\.0\.0\/0/g" $TARGET_DIR/postgres/data/pg_hba.conf
				echo "#!/bin/sh" > /etc/rc.d/init.d/postgres
				echo "#" >> /etc/rc.d/init.d/postgres
				echo "# chkconfig: 3 70 05" >> /etc/rc.d/init.d/postgres
				echo "#" >> /etc/rc.d/init.d/postgres
				echo "PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin" >> /etc/rc.d/init.d/postgres
				echo "case \"\$1\" in" >> /etc/rc.d/init.d/postgres
				echo "start)" >> /etc/rc.d/init.d/postgres
				echo "	su postgres -c '/usr/pgsql*/bin/pg_ctl start -D /opt/postgres/data'" >> /etc/rc.d/init.d/postgres
				echo ";;" >> /etc/rc.d/init.d/postgres
				echo "stop)" >> /etc/rc.d/init.d/postgres
				echo "	su postgres -c '/usr/pgsql*/bin/pg_ctl stop -D /opt/postgres/data'" >> /etc/rc.d/init.d/postgres
				echo ";;" >> /etc/rc.d/init.d/postgres
				echo "esac" >> /etc/rc.d/init.d/postgres
				chmod 755 /etc/rc.d/init.d/postgres 2>>$ERROR
				chkconfig --add postgres 2>>$ERROR
				chkconfig --level 3 postgres on 2>>$ERROR
				service postgres start >$ILOG 2>>$ERROR
				ret=$?
				if [ $ret -ne 0 ]
				then
					Screen_output 0 "The Postgres Server failed to start !!"
					echo " Errorcode : $ret"
					echo ""
					Continue
				else
					touch $INSTALL_LOG_DIR/postgresinstalled.log
				fi
			fi
		fi
	fi
}

Install_flowable()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install Flowable BMP.                                           *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing Flowable ***" >>$ERROR
	unzip $FLOWABLEFILE -d $TARGET_DIR >$ILOG 2>>$ERROR
	ret=$?
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "The installation of Flowable failed."
		echo ""
		echo " Errorcode : $ret"
		Abort_install
	else
		if [ "$COMBOINSTALL" = "true" ]
		then
			unset EDBHOME PGDATABASE PGPORT PGLOCALEDIR PGDATA
		fi
		cd $INSTALL_FILE_DIR
		su postgres -c '/usr/pgsql*/bin/psql -f misc/initflowable.sql' >$ILOG 2>>$ERROR
		su postgres -c '/usr/pgsql*/bin/psql -U flowable -d flowable -f /opt/flowable-*/database/create/all/flowable.postgres.all.create.sql' >$ILOG 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]	
		then
			Screen_output 0 "The installation of Flowable failed."
			echo ""
			echo " Errorcode : $ret"
			Abort_install
		else
			touch $INSTALL_LOG_DIR/flowable.log
		fi
	fi
}

Install_tomcat()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install Apache Tomcat.                                          *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing Tomcat ***" >>$ERROR
	gunzip -c $APACHEFILE > $INSTALL_LOG_DIR/apache.tar 2>>$ERROR
	tar xvf $INSTALL_LOG_DIR/apache.tar -C $TARGET_DIR >$ILOG 2>>$ERROR
	ret=$?
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "The installation of Tomcat failed."
		echo ""
		echo " Errorcode : $ret"
		echo "The installation of Tomcat failed"
		Abort_install
	else
		rm -rf $INSTALL_LOG_DIR/apache.tar
		echo "JAVA_OPTS=\"-XX:+CMSClassUnloadingEnabled\"" >>$TARGET_DIR/apache-tomcat-$VAPACHE/bin/setenv.sh
		cp $INSTALL_FILE_DIR/misc/post*jar $TARGET_DIR/apa*/lib >$ILOG 2>>$ERROR
		if [ "$COMBOINSTALL" = "true" ]
		then
			sed -i -e 's/8009/9009/g' $TARGET_DIR/apache*/conf/server.xml >$ILOG 2>>$ERROR
		fi
		touch $INSTALL_LOG_DIR/tomcat.log
	fi
}

Install_flowable_wars()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install all Flowable applications / war files.                  *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing Flowable wars ***" >>$ERROR
	APADIR=`dirname $TARGET_DIR/apa*/conf/context.xml`
	mkdir -p $APADIR/Catalina/localhost
	for wars in $TARGET_DIR/flowable*/wars/flowable*.war
	do
		WARFILE=`basename $wars`
		case $WARFILE in
			flowable-rest.war)
				cp $TARGET_DIR/flowable*/wars/flowable-rest.war $TARGET_DIR/apache-tomcat-*/webapps >$ILOG 2>>$ERROR
				mkdir -p $INSTALL_LOG_DIR/WEB-INF/classes >$ILOG 2>>$ERROR
				cp $INSTALL_FILE_DIR/flowable-classes/db.properties $INSTALL_LOG_DIR/WEB-INF/classes >$ILOG 2>>$ERROR
				cd $INSTALL_LOG_DIR
				jar uvf $TARGET_DIR/apache-tomcat-*/webapps/flowable-rest.war WEB-INF >$ILOG 2>>$ERROR
				cd $INSTALL_FILE_DIR
				rm -rf $INSTALL_LOG_DIR/WEB-INF >$ILOG 2>>$ERROR
			;;
			flowable-admin.war)
				cp $TARGET_DIR/flowable*/wars/flowable-admin.war $TARGET_DIR/apache-tomcat-*/webapps >$ILOG 2>>$ERROR
				mkdir -p $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app >$ILOG 2>>$ERROR
				cd $INSTALL_LOG_DIR >$ILOG 2>>$ERROR
				jar xvf $TARGET_DIR/flow*/wars/flowable-admin.war -x WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				sed -i -e 's/datasource.driver=org.h2.Driver/#datasource.driver=org.h2.Driver/g' $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				sed -i -e 's/datasource.url=jdbc:h2:mem:flowable;DB_CLOSE_DELAY=-1/#datasource.url=jdbc:h2:mem:flowable;DB_CLOSE_DELAY=-1/g' $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				sed -i -e "s/localhost/$NEWHOSTNAME/g" $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				echo "datasource.jndi.name=jdbc/flowable-admin" >>$INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties
				echo "datasource.jndi.resourceRef=true" >>$INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties
				jar uvf $TARGET_DIR/apache-tomcat-*/webapps/flowable-admin.war WEB-INF >$ILOG 2>>$ERROR
				cd $INSTALL_FILE_DIR
				rm -rf $INSTALL_LOG_DIR/WEB-INF >$ILOG 2>>$ERROR
			;;
			flowable-idm.war)
				cp $TARGET_DIR/flowable*/wars/flowable-idm.war $TARGET_DIR/apache-tomcat-*/webapps >$ILOG 2>>$ERROR
				mkdir -p $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app >$ILOG 2>>$ERROR
				cd $INSTALL_LOG_DIR >$ILOG 2>>$ERROR
				jar xvf $TARGET_DIR/flow*/wars/flowable-idm.war -x WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				sed -i -e 's/datasource.driver=org.h2.Driver/#datasource.driver=org.h2.Driver/g' $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				sed -i -e 's/datasource.url=jdbc:h2:mem:flowable;DB_CLOSE_DELAY=-1/#datasource.url=jdbc:h2:mem:flowable;DB_CLOSE_DELAY=-1/g' $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				sed -i -e "s/localhost/$NEWHOSTNAME/g" $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				echo "datasource.jndi.name=jdbc/flowable-idm" >>$INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties
				echo "datasource.jndi.resourceRef=true" >>$INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties
				jar uvf $TARGET_DIR/apache-tomcat-*/webapps/flowable-idm.war WEB-INF >$ILOG 2>>$ERROR
				cd $INSTALL_FILE_DIR
				rm -rf $INSTALL_LOG_DIR/WEB-INF >$ILOG
			;;
			flowable-modeler.war)
				cp $TARGET_DIR/flowable*/wars/flowable-modeler.war $TARGET_DIR/apache-tomcat-*/webapps >$ILOG 2>>$ERROR
				mkdir -p $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app >$ILOG 2>>$ERROR
				cd $INSTALL_LOG_DIR >$ILOG 2>>$ERROR
				jar xvf $TARGET_DIR/flow*/wars/flowable-modeler.war -x WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				sed -i -e 's/datasource.driver=org.h2.Driver/#datasource.driver=org.h2.Driver/g' $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				sed -i -e 's/datasource.url=jdbc:h2:mem:flowable;DB_CLOSE_DELAY=-1/#datasource.url=jdbc:h2:mem:flowable;DB_CLOSE_DELAY=-1/g' $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				sed -i -e "s/localhost/$NEWHOSTNAME/g" $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				echo "datasource.jndi.name=jdbc/flowable-modeler" >>$INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties
				echo "datasource.jndi.resourceRef=true" >>$INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties
				jar uvf $TARGET_DIR/apache-tomcat-*/webapps/flowable-modeler.war WEB-INF >$ILOG 2>>$ERROR
				cd $INSTALL_FILE_DIR
				rm -rf $INSTALL_LOG_DIR/WEB-INF >$ILOG 2>>$ERROR
			;;
			flowable-task.war)
				cp $TARGET_DIR/flowable*/wars/flowable-task.war $TARGET_DIR/apache-tomcat-*/webapps >$ILOG 2>>$ERROR
				mkdir -p $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app >$ILOG 2>>$ERROR
				cd $INSTALL_LOG_DIR >$ILOG 2>>$ERROR
				jar xvf $TARGET_DIR/flow*/wars/flowable-task.war -x WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				sed -i -e 's/datasource.driver=org.h2.Driver/#datasource.driver=org.h2.Driver/g' $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				sed -i -e 's/datasource.url=jdbc:h2:mem:flowable;DB_CLOSE_DELAY=-1/#datasource.url=jdbc:h2:mem:flowable;DB_CLOSE_DELAY=-1/g' $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				sed -i -e "s/localhost/$NEWHOSTNAME/g" $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				sed -i -e "s/#email.host=flowabledemo/email.host=$NEWHOSTNAME/g" $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				sed -i -e 's/#email.port=1025/email.port=2525/g' $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				sed -i -e 's/#email.useCredentials=false/email.useCredentials=false/g' $INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties >$ILOG 2>>$ERROR
				echo "datasource.jndi.name=jdbc/flowable-task" >>$INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties
				echo "datasource.jndi.resourceRef=true" >>$INSTALL_LOG_DIR/WEB-INF/classes/META-INF/flowable-ui-app/flowable-ui-app.properties
				jar uvf $TARGET_DIR/apache-tomcat-*/webapps/flowable-task.war WEB-INF >$ILOG 2>>$ERROR
				cd $INSTALL_FILE_DIR
				rm -rf $INSTALL_LOG_DIR/WEB-INF >$ILOG 2>>$ERROR
			;;
		esac
	cp $INSTALL_FILE_DIR/flowable-classes/flowable-*.xml $APADIR/Catalina/localhost
	done
	if [ "$COMBOINSTALL" = "false" ]
	then
	  if [ ! -f $INSTALL_LOG_DIR/phoc.log ]
	  then
	  		Check_war $INSTALL_FILE_DIR/options/posthoc.war WEB-INF/DataLocation.properties
			if [ "$WARCONTENT" = "true" ]
			then
				Modify_posthoc
				cp $INSTALL_FILE_DIR/options/posthoc.war $TARGET_DIR/apa*/webapps >$ILOG 2>>$ERROR
				ret=$?
				if [ $ret -ne 0 ]
				then
					Screen_output 0 "The posthoc.war file failed to copy !!"
					echo " Errorcode : $ret"
					echo ""
					Continue
				else
					touch $INSTALL_LOG_DIR/phoc.log
					rm -rf $INSTALL_LOG_DIR/posthoc.war
				fi
			else
				Screen_output 0 "The posthoc.war file does not contain a DataLocation.properties file !!"
				echo ""
				Continue
			fi
		fi
	fi
	touch $INSTALL_LOG_DIR/flowablewars.log
}

Install_webpage()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install the Welcome web page shown by going to the default      *
# * URL once the VM has been installed completely.                                     *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing webpage ***" >>$ERROR
	systemctl enable httpd >$ILOG 2>&1
	unzip $INSTALL_FILE_DIR/web/web.zip -d /var/www/html >$ILOG 2>>$ERROR
	cp -r $INSTALL_FILE_DIR/web/scripts /var/www/html 2>>$ERROR
	cp $INSTALL_FILE_DIR/misc/README.txt /root/README.txt 2>>$ERROR
	sed -i -e "s/version : /version : $VMVERSION/g" /root/README.txt 2>>$ERROR
	chmod 755 /var/www/html/scripts/systemstatus 2>>$ERROR
	/var/www/html/scripts/systemstatus 2>>$ERROR
	echo "0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59 * * * * root /var/www/html/scripts/systemstatus" >> /etc/crontab 2>>$ERROR
	echo "<VirtualHost *:80>">>/etc/httpd/conf/httpd.conf
	echo "ServerName $NEWHOSTNAME">>/etc/httpd/conf/httpd.conf
	echo "DocumentRoot /var/www/html">>/etc/httpd/conf/httpd.conf
	echo "<Directory \"/var/www/html\">">>/etc/httpd/conf/httpd.conf
	echo "RewriteEngine on">>/etc/httpd/conf/httpd.conf
    echo "RewriteCond %{REQUEST_FILENAME} -f [OR]">>/etc/httpd/conf/httpd.conf
    echo "RewriteCond %{REQUEST_FILENAME} -d">>/etc/httpd/conf/httpd.conf
    echo "RewriteRule ^ - [L]">>/etc/httpd/conf/httpd.conf
    echo "RewriteRule ^ index.html">>/etc/httpd/conf/httpd.conf
    echo "</Directory>">>/etc/httpd/conf/httpd.conf
    echo "</VirtualHost>">>/etc/httpd/conf/httpd.conf
	/usr/sbin/apachectl start 2>>$ERROR
	touch $INSTALL_LOG_DIR/webpage.log
}

Install_war()
{
# **************************************************************************************
# *                                                                                    *
# * This function will check for WAR files in the installation directory. If any are   *
# * are present, it will give the user the option to install them into JBoss.          *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing war files ***" >>$ERROR
	for war in $INSTALL_FILE_DIR/options/*.war
	do
		WARFILE=`basename $war`
		case $WARFILE in
			posthoc.war)
				if [ ! -f $INSTALL_LOG_DIR/phoc.log ]
				then
					Check_war $war WEB-INF/DataLocation.properties
					if [ "$WARCONTENT" = "true" ]
					then
						Modify_posthoc
						Deploy_war $INSTALL_LOG_DIR/posthoc.war
						rm -rf $INSTALL_LOG_DIR/posthoc.war
					else
						Screen_output 0 "The posthoc.war file does not contain a DataLocation.properties file !!"
						echo ""
						Continue
					fi
				fi
			;;
			ssofi.war)
				if [ ! -f $INSTALL_LOG_DIR/ssofi.log ]
				then
					cp $INSTALL_FILE_DIR/options/ssofi.war $INSTALL_LOG_DIR
					cd $INSTALL_LOG_DIR
					jar xvf ssofi.war -x WEB-INF/EmailNotification.properties >$ILOG 2>>$ERROR
					sed -i -e "s/interstagedemo/$NEWHOSTNAME/g" $INSTALL_LOG_DIR/WEB-INF/EmailNotification.properties 2>>$ERROR
					jar uvf $INSTALL_LOG_DIR/ssofi.war WEB-INF >$ILOG 2>>$ERROR
					cd $INSTALL_FILE_DIR
					Deploy_war $INSTALL_LOG_DIR/ssofi.war
					rm -rf $INSTALL_LOG_DIR/ssofi.war
				fi
			;;
			aa.war)
				if [ ! -f $INSTALL_LOG_DIR/aa.log ]
				then
					cp $INSTALL_FILE_DIR/options/aa.war $INSTALL_LOG_DIR
					mkdir $TARGET_DIR/AgileAdapterData 2>>$ERROR
					mkdir $TARGET_DIR/BPM_Temp_Files 2>>$ERROR
					mkdir -p $INSTALL_LOG_DIR/WEB-INF/lib >$ILOG 2>>$ERROR
					cp $TARGET_DIR/engine/client/lib/iFlow.jar $INSTALL_LOG_DIR/WEB-INF/lib >$ILOG 2>>$ERROR
					cd $INSTALL_LOG_DIR
					jar xvf $INSTALL_LOG_DIR/aa.war -x WEB-INF/EmailNotification.properties >$ILOG 2>>$ERROR
					jar xvf $INSTALL_LOG_DIR/aa.war -x WEB-INF/iFlowClient.properties >$ILOG 2>>$ERROR
					sed -i -e "s/127.0.0.1/$NEWHOSTNAME/g" $INSTALL_LOG_DIR/WEB-INF/EmailNotification.properties 2>>$ERROR
					sed -i -e "s/interstagedemo/$NEWHOSTNAME/g" $INSTALL_LOG_DIR/WEB-INF/iFlowClient.properties 2>>$ERROR
					sed -i -e "s/ApiPassword=\*\*\*\*\*\*\*\*/ApiPassword=$APIPASSWORD/g" $INSTALL_LOG_DIR/WEB-INF/iFlowClient.properties 2>>$ERROR
					sed -i -e "s/SuperPassword=\*\*\*\*\*\*\*\*/SuperPassword=$SUPERPASSWORD/g" $INSTALL_LOG_DIR/WEB-INF/iFlowClient.properties 2>>$ERROR
					sed -i -e "s/DmsPassword=\*\*\*\*\*\*\*\*/DmsPassword=$DMSPASSWORD/g" $INSTALL_LOG_DIR/WEB-INF/iFlowClient.properties 2>>$ERROR
					sed -i -e 's/SSOToken=\*\*\*\*\*\*\*\*/#SSOToken=\*\*\*\*\*\*\*\*/g' $INSTALL_LOG_DIR/WEB-INF/iFlowClient.properties 2>>$ERROR
					jar uvf aa.war WEB-INF >$ILOG 2>>$ERROR
					cd $INSTALL_FILE_DIR
					rm -rf $INSTALL_LOG_DIR/WEB-INF
					Deploy_war $INSTALL_LOG_DIR/aa.war
					rm -rf $INSTALL_LOG_DIR/aa.war
				fi
			;;
		esac
	done
	Restart_Jboss
	$TARGET_DIR/engine/server/deployment/bin/exportProperties.sh $INSTALL_LOG_DIR/ibpmprop enterprisedb Fujitsu1 >$ILOG 2>>$ERROR
	echo "ByPassJBoss6EjbLoadAfterEjbCreate=false" >>$INSTALL_LOG_DIR/ibpmprop
	$TARGET_DIR/engine/server/deployment/bin/importProperties.sh $INSTALL_LOG_DIR/ibpmprop enterprisedb Fujitsu1 >$ILOG 2>>$ERROR
	if  [ -f $TARGET_DIR/SSOFI_Sessions/config.txt ]
	then
		sed -i -e 's/# authStyle=local/authStyle=local/g' $TARGET_DIR/SSOFI_Sessions/config.txt >$ILOG 2>>$ERROR
		sed -i -e 's/# authStyle=ldap//g' $TARGET_DIR/SSOFI_Sessions/config.txt >$ILOG 2>>$ERROR
		sed -i -e 's/authStyle=ldap//g' $TARGET_DIR/SSOFI_Sessions/config.txt >$ILOG 2>>$ERROR
		sed -i -e "s/baseURL.*/baseURL=http:\/\/$NEWHOSTNAME:49950\/ssofi\//g" $TARGET_DIR/SSOFI_Sessions/config.txt >$ILOG 2>>$ERROR
		sed -i -e "s/rootURL.*/rootURL=http:\/\/$NEWHOSTNAME:49950\/ssofi\//g" $TARGET_DIR/SSOFI_Sessions/config.txt >$ILOG 2>>$ERROR
	fi
	touch $INSTALL_LOG_DIR/warinstalled.log
}

Start_tomcat()
{
# **************************************************************************************
# *                                                                                    *
# * This function will configure the integration between Flowable and Tomcat           *
# * and create the startup script, and start Tomcat.                                   *
# *                                                                                    *
# **************************************************************************************
	echo "*** Starting Tomcat ***" >>$ERROR
	echo "#!/bin/sh" > /etc/rc.d/init.d/flowable
	echo "#" >> /etc/rc.d/init.d/flowable
	echo "# chkconfig: 3 75 05" >> /etc/rc.d/init.d/flowable
	echo "#" >> /etc/rc.d/init.d/flowable
	echo "PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin" >> /etc/rc.d/init.d/flowable
	echo "case \"\$1\" in" >> /etc/rc.d/init.d/flowable
	echo "start)" >> /etc/rc.d/init.d/flowable
	echo "	$TARGET_DIR/apache-tomcat-*/bin/catalina.sh run &" >> /etc/rc.d/init.d/flowable
	echo "	echo \$! >$TARGET_DIR/utilities/tomcatpid" >> /etc/rc.d/init.d/flowable
	echo ";;" >> /etc/rc.d/init.d/flowable
	echo "stop)" >> /etc/rc.d/init.d/flowable
	echo "	kill \`cat $TARGET_DIR/utilities/tomcatpid\`" >> /etc/rc.d/init.d/flowable
	echo ";;" >> /etc/rc.d/init.d/flowable
	echo "esac" >> /etc/rc.d/init.d/flowable
	chmod 755 /etc/rc.d/init.d/flowable 2>>$ERROR
	chkconfig --add flowable 2>>$ERROR
	chkconfig --level 3 flowable on 2>>$ERROR
	service flowable start >$ILOG 2>>$ERROR
	touch $INSTALL_LOG_DIR/tomcatstart.log
}

Install_alfresco()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install Alfresco.                                               *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing Alfresco ***" >>$ERROR
	yum -y install fontconfig libSM libICE libXrender libXext cups-libs >$ILOG 2>>$ERROR
	chmod 755 $ALFRESCOFILE
	$TARGET_DIR/edb/9.5AS/bin/psql -U enterprisedb -c 'create database alfresco' >$ILOG 2>>$ERROR
	$TARGET_DIR/edb/9.5AS/bin/psql -U enterprisedb -c "create user alfresco password 'alfresco'" >$ILOG 2>>$ERROR
	$TARGET_DIR/edb/9.5AS/bin/psql -U enterprisedb -c 'grant all privileges on database alfresco to alfresco' >$ILOG 2>>$ERROR
	$ALFRESCOFILE<<IALFRESCO >$ILOG 2>>$ERROR
y
1
2
n
n
y
y
y
y
y
y
y

jdbc:postgresql://localhost:5444/alfresco


alfresco
alfresco
alfresco
$NEWHOSTNAME



8010


Fujitsu1
Fujitsu1
y

y
n
n
IALFRESCO
	JAVA8DIR=`basename /usr/java/jdk1.8*`
	sed -i -e "s/JAVA_HOME=\/usr/JAVA_HOME=\/usr\/java\/$JAVA8DIR/g" $TARGET_DIR/alfresco-community/tomcat/bin/setenv.sh
	rm -rf $TARGET_DIR/alfresco-community/tomcat/lib/postgres*jar
	cp $INSTALL_FILE_DIR/misc/postgres*jar $TARGET_DIR/alfresco-community/tomcat/lib 2>>$ERROR
	echo "" >> $TARGET_DIR/AgileAdapterData/iFlowClient.properties 2>>$ERROR
	echo "cmis_user=admin" >> $TARGET_DIR/AgileAdapterData/iFlowClient.properties 2>>$ERROR
	echo "cmis_password=Fujitsu1" >> $TARGET_DIR/AgileAdapterData/iFlowClient.properties 2>>$ERROR
	echo "cmis_url=http://$NEWHOSTNAME:8080/alfresco/api/-default/cmis/versions/1.1/atom" >> $TARGET_DIR/AgileAdapterData/iFlowClient.properties 2>>$ERROR
	echo "cmis_repository=" >> $TARGET_DIR/AgileAdapterData/iFlowClient.properties 2>>$ERROR
	echo "" >> $TARGET_DIR/alfresco-community/tomcat/shared/classes/alfresco-global.properties
	service alfresco start >$ILOG 2>>$ERROR
	cd $INSTALL_FILE_DIR
	while ! service alfresco status | grep "tomcat already running" >$ILOG 2>>$ERROR
	do
		sleep 5
	done
	sed -i -e '/start () {/r misc/alfresco.start' /etc/rc.d/init.d/alfresco
	ret=$?
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "The Alfresco Service failed to start !!"
		Continue
	fi
	if [ -f $TARGET_DIR/alfresco-community/tomcat/shared/classes/alfresco-global.properties ]
	then
		sed -i -e 's/db.pool.max=275/db.pool.max=50/g' $TARGET_DIR/alfresco-community/tomcat/shared/classes/alfresco-global.properties 2>>$ERROR
		touch $INSTALL_LOG_DIR/alfresco.log
	fi
}

Install_elastic()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install the elastic search package.                             *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing Elastic Search ***" >>$ERROR
	rpm -i $ELASTICFILE >$ILOG 2>>$ERROR
	ret=$?
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "Elastic Search failed to install !!"
		echo " Errorcode : $ret"
		echo ""
		Continue
	else
		sed -i -e "/#network.host: /c\network.host: $NEWHOSTNAME" /etc/elasticsearch/elasticsearch.yml 2>>$ERROR
		sed -i -e '/#node.attr.rack: r1/ a script.inline: true' /etc/elasticsearch/elasticsearch.yml 2>>$ERROR
		sed -i -e '/#node.attr.rack: r1/ a script.stored: true' /etc/elasticsearch/elasticsearch.yml 2>>$ERROR
		echo "http.cors.enabled: true" >> /etc/elasticsearch/elasticsearch.yml
		echo "http.cors.allow-origin: \"*\"" >> /etc/elasticsearch/elasticsearch.yml
		systemctl daemon-reload >$ILOG 2>&1
		systemctl enable elasticsearch.service >$ILOG 2>&1
		sed -i -e 's/killproc -p \$pidfile -d 86400 \$prog/kill `cat \$pidfile`/g' /etc/rc.d/init.d/elasticsearch 2>>$ERROR
		if [ -f /etc/elasticsearch/jvm.options ]
		then
			if [ "$APPLICATION" = "IBPM" ]
			then
				sed -i -e 's/Xms2g/Xms500m/g' /etc/elasticsearch/jvm.options 2>>$ERROR
				sed -i -e 's/Xmx2g/Xmx500m/g' /etc/elasticsearch/jvm.options 2>>$ERROR
			fi
		fi
		service elasticsearch start>$ILOG 2>&1
		sleep 15
		touch $INSTALL_LOG_DIR/elasticsearch.log
	fi
}

Install_esgui()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install the Elastic Search GUI (E.S. Head)                      *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing E.S. GUI ***" >>$ERROR
	unzip $ESHEADFILE -d $TARGET_DIR >$ILOG 2>>$ERROR
	ret=$?
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "The Elastic Search Head installation failed to install !!"
		Continue
	else
		cd $TARGET_DIR/elasticsearch-head-master
		sed -i -e "s/localhost:9100/$NEWHOSTNAME:9100/g" $TARGET_DIR/elasticsearch-head-master/proxy/index.js
		npm install >$ILOG 2>>$ERROR
		cd $TARGET_DIR
		NODEDIR=`dirname $TARGET_DIR/node*/bin/node`
		echo "#!/bin/sh" > /etc/rc.d/init.d/eshead
		echo "#" >> /etc/rc.d/init.d/eshead
		echo "# chkconfig: 3 75 04" >> /etc/rc.d/init.d/eshead
		echo "#" >> /etc/rc.d/init.d/eshead
		echo "PATH=$NODEDIR:/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin" >> /etc/rc.d/init.d/eshead
		echo "cd $TARGET_DIR/elasticsearch-head-master" >> /etc/rc.d/init.d/eshead
		echo "nohup npm run start &" >> /etc/rc.d/init.d/eshead
		chmod 755 /etc/rc.d/init.d/eshead
		chkconfig --add eshead >$ILOG 2>>$ERROR
		chkconfig --level 3 eshead on >$ILOG 2>>$ERROR
		touch $INSTALL_LOG_DIR/esgui.log
	fi
}

Deploy_war()
{
# **************************************************************************************
# *                                                                                    *
# * This function will deploy war files using the JBoss cli script                     *
# *                                                                                    *
# **************************************************************************************
	warname=`echo $1|rev|cut -f1 -d"/"|rev`
	appname=`echo $warname|cut -f1 -d"."`
	echo "connect" > $INSTALL_LOG_DIR/cliscript 2>>$ERROR
	echo "deploy $1 --server-groups=iflow-server-group" >> $INSTALL_LOG_DIR/cliscript 2>>$ERROR
	echo "quit" >> $INSTALL_LOG_DIR/cliscript 2>>$ERROR
	$TARGET_DIR/jboss-eap-6.4/bin/jboss-cli.sh --file=$INSTALL_LOG_DIR/cliscript 2>>$ERROR
	ret=$?
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "The $warname file failed to deploy !!"
		echo " Errorcode : $ret"
		echo ""
		Continue
	else
		rm -rf $INSTALL_LOG_DIR/cliscript
		touch $INSTALL_LOG_DIR/$appname.log
	fi
}

Install_rea()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install the REA application.                                    *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing REA ***" >>$ERROR
	if ! grep "path.repo" /etc/elasticsearch/elasticsearch.yml
	then
		echo "path.repo: $TARGET_DIR/esbackup/my_backup">>/etc/elasticsearch/elasticsearch.yml 2>>$ERROR
	fi
	mkdir -p $TARGET_DIR/esbackup/my_backup 2>>$ERROR
	chown elasticsearch:elasticsearch $TARGET_DIR/esbackup 2>>$ERROR
	service elasticsearch stop >$ILOG 2>>$ERROR
	sleep 2
	service elasticsearch start >$ILOG 2>>$ERROR
	if ! service elasticsearch status | grep "active (running)" >$ILOG
	then
		Screen_output 0 "The Elastic Search Service is not running !!"
		Continue
	else
		sleep 20
	fi
	if [ ! -f $INSTALL_LOG_DIR/rearepo ] >$ILOG
	then
		curl -XPUT "http://$NEWHOSTNAME:9200/_snapshot/my_backup" -d '{ "type": "fs", "settings": { "compress": true, "location": "/opt/esbackup/my_backup" }}' >$ILOG 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "The Elastic Search repository failed to get created !! "
			Continue
		else
			touch $INSTALL_LOG_DIR/rearepo
		fi
	fi
	if [ ! -f $INSTALL_LOG_DIR/reasnapshot ] >$ILOG
	then
		curl -XPUT "http://$NEWHOSTNAME:9200/_snapshot/my_backup/snapshot_1?wait_for_completion=true" >$ILOG 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "The Elastic Search snapshot failed to get created !!"
			Continue
		else
			touch $INSTALL_LOG_DIR/reasnapshot
		fi
	fi
	if [ ! -f $INSTALL_LOG_DIR/readata ] >$ILOG
	then
		tar -xvf $INSTALL_FILE_DIR/rea/mybackup.tar -C /opt/esbackup >$ILOG 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "The Elastic Search data file failed to unzip !!"
			Continue
		else
			touch $INSTALL_LOG_DIR/readata
		fi
	fi
	curl -XPOST "http://$NEWHOSTNAME:9200/.kibana/_close" >$ILOG 2>>$ERROR
	if [ ! -f $INSTALL_LOG_DIR/rearestore ] >$ILOG
	then
		curl -XPOST "http://$NEWHOSTNAME:9200/_snapshot/my_backup/snapshot_1/_restore" >$ILOG 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "The Elastic Search snapshot failed to restore !!"
			Continue
		else
			touch $INSTALL_LOG_DIR/rearestore
		fi
	fi
	cp $INSTALL_FILE_DIR/rea/nginx.conf /etc/nginx >$ILOG 2>>$ERROR
	cp $INSTALL_FILE_DIR/rea/kibana.conf /etc/nginx/conf.d >$ILOG 2>>$ERROR
	htpasswd -bc /etc/nginx/htpasswd.users demo Fujitsu1 >$ILOG 2>>$ERROR
	if [ ! -f $INSTALL_LOG_DIR/reaui ]
	then
		unzip -o $INSTALL_FILE_DIR/rea/rea.zip -d $TARGET_DIR >$ILOG 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "The Elastic Search UI file failed to unzip !!"
			Continue
		else
			touch $INSTALL_LOG_DIR/reaui
		fi
	fi
	setsebool -P httpd_can_network_connect 1 >$ILOG 2>>$ERROR
	systemctl start nginx >$ILOG 2>>$ERROR
	systemctl enable nginx >$ILOG 2>>$ERROR
	if ! systemctl status nginx | grep "active (running)" >$ILOG 2>>$ERROR
	then
		Screen_output 0 "The nginx Service is not running !!"
		Continue
	fi
	export PATH
	if [ ! -f $INSTALL_LOG_DIR/pm2 ]
	then
		npm install pm2 -g >$ILOG 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "PM2 failed to install !!"
			Continue
		else
			touch $INSTALL_LOG_DIR/pm2
		fi
	fi
	cd $TARGET_DIR/rea/nodeapp/clientmodule
	npm install >$ILOG 2>>$ERROR
	pm2 start capiserver.js >$ILOG 2>>$ERROR
	ret=$?
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "The PM2 CAPI server failed to start !!"
		Continue
	fi
	cd $TARGET_DIR/rea/nodeapp/dcmodule
	npm install >$ILOG 2>>$ERROR
	pm2 start dcserver.js >$ILOG 2>>$ERROR
	ret=$?
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "The PM2 DC server failed to start !!"
		Continue
	fi
	cd $TARGET_DIR/rea/nodeapp/apimodule
	npm install >$ILOG 2>>$ERROR
	pm2 start server.js >$ILOG 2>>$ERROR
	ret=$?
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "The PM2 API server failed to start !!"
		Continue
	else
		touch $INSTALL_LOG_DIR/rea.log
	fi
	cd $INSTALL_FILE_DIR
}

Install_chat()
{
# **************************************************************************************
# *                                                                                    *
# * This function will install the chat functionality.                                 *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installing chat ***" >>$ERROR
	echo "#!/bin/sh" > /etc/rc.d/init.d/chat.sh
	echo "#" >> /etc/rc.d/init.d/chat.sh
	echo "# chkconfig: 3 85 04" >>/etc/rc.d/init.d/chat.sh
	echo "#" >> /etc/rc.d/init.d/chat.sh
	echo "PATH=REPLACE/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin" >> /etc/rc.d/init.d/chat.sh
	echo "cd $TARGET_DIR/chat" >> /etc/rc.d/init.d/chat.sh
	echo "node app.js &" >> /etc/rc.d/init.d/chat.sh
	if [ -d $INSTALL_FILE_DIR/options/chat ]
	then
		cp -r $INSTALL_FILE_DIR/options/chat $TARGET_DIR 2>>$ERROR
	fi
	if [ -f $INSTALL_FILE_DIR/software/node*xz ]
	then
		gunzip -fc $INSTALL_FILE_DIR/software/node*xz >$INSTALL_LOG_DIR/node.tar 2>>$ERROR
		tar xvf $INSTALL_LOG_DIR/node.tar -C $INSTALL_LOG_DIR > $ILOG 2>>$ERROR
		mkdir $TARGET_DIR/node$VNODE 2>>$ERROR
		mv $INSTALL_LOG_DIR/node*x64/* $TARGET_DIR/node$VNODE 2>>$ERROR
		sed -i -e "s|REPLACE|$TARGET_DIR/node$VNODE|g" /etc/rc.d/init.d/chat.sh 2>>$ERROR
		PATH=$PATH:$TARGET_DIR/node$VNODE/bin 2>>$ERROR
		rm -rf $INSTALL_LOG_DIR/node.tar
		rm -rf $INSTALL_LOG_DIR/node*x64
		chmod 755 /etc/rc.d/init.d/chat.sh 2>>$ERROR
		chkconfig --add chat.sh 2>>$ERROR
		chkconfig --level 3 chat.sh on 2>>$ERROR
		cd $TARGET_DIR/chat 2>>$ERROR
		npm install > $ILOG 2>&1
		service chat.sh start > $ILOG 2>>$ERROR
		ret=$?
		if [ $ret -ne 0 ]
		then
			Screen_output 0 "The chat service failed to start !!"
			echo " Errorcode : $ret"
			echo ""
			Continue
		else
			cd $INSTALL_FILE_DIR
			touch $INSTALL_LOG_DIR/chat.log
		fi
	fi
}

Create_appversion()
{
# **************************************************************************************
# *                                                                                    *
# * This function will a json file containing all applications and versions installed. *
# *                                                                                    *
# **************************************************************************************
	echo "*** Creating appversion json file ***" >>$ERROR
	INSTALLDATE=`date`
	if [ -f /etc/centos-release ]
	then
		OSRELEASE=`cat /etc/centos-release`
	else
		OSRELEASE="unknown"
	fi
	CHATVERSION="unknown"
	case "$APPLICATION" in
		IBPM)
			if [ "$IBPMDB" = "postgresas" ]
			then
				DBVERSION="PostgresAS $VPPAS"
			else
				DBVERSION="Oracle XE $VORACLE"
			fi
			if [ "$INSTALLJBOSS" = "true" ]
			then
				JBOSS_VERSION="$VJBOSS"
				if [ "$VJBOSS" = "6.4" ]
				then
					JBOSS_VERSION="6.4.9"
				fi
				JBOSSINSTALLED="true"
			else
				JBOSS_VERSION="not installed"
				JBOSSINSTALLED="false"
			fi
			if [ "$INSTALLIBPM" = "true" ]
			then
				IBPM_VERSION=`cat $TARGET_DIR/engine/server/instance/default/console/conf/console.conf|grep "Build"|cut -f2 -d "="|cut -f2 -d"F"`
				jar xvf $INSTALL_FILE_DIR/options/aa.war WEB-INF/BuildInfo.properties >$ILOG
				AAVERSION=`cat WEB-INF/BuildInfo.properties|cut -f2 -d"="|grep "-"`
				rm -rf WEB-INF >$ILOG
				jar xvf $INSTALL_FILE_DIR/options/posthoc.war WEB-INF/BuildInfo.properties >$ILOG
				MAILVERSION=`cat WEB-INF/BuildInfo.properties|cut -f2 -d"="|grep "-"`
				rm -rf WEB-INF >$ILOG
				jar xvf $INSTALL_FILE_DIR/options/ssofi.war WEB-INF/BuildInfo.properties >$ILOG
				SSOFIVERSION=`cat WEB-INF/BuildInfo.properties|cut -f2 -d"="|grep "-"`
				rm -rf WEB-INF >$ILOG
				BALVERSION=`cat $INSTALL_FILE_DIR/bal-jars/*properties|cut -f2 -d"="|grep "-"`
				IBPMINSTALLED="true"
			else
				IBPM_VERSION="not installed"
				AAVERSION="not installed"
				MAILVERSION="not installed"
				SSOFIVERSION="not installed"
				BALVERSION="not installed"
				IBPMINSTALLED="false"
			fi
			if [ "$ALFRESCO" = "true" ]
			then
				ALFRESCOVERSION="$VALFRESCO"
				ALFRESCOINSTALLED="true"
			else
				ALFRESCOVERSION="not installed"
				ALFRESCOINSTALLED="false"
			fi
			if [ "$COMBOINSTALL" = "true" ]
			then
				FLOWABLEVERSION="$VFLOWABLE"
				TOMCATVERSION="$VAPACHE"
				FLOWABLEINSTALLED="true"
			else
				FLOWABLEVERSION="not installed"
				TOMCATVERSION="not installed"
				FLOWABLEINSTALLED="false"
			fi
			REAVERSION="not installed"
			DBINSTALLED="true"
			ESINSTALLED="true"
			REAINSTALLED="false"
			NGINXINSTALLED="false"
			NGINXVERSION="not installed"
		;;
		FLOWABLE)
			DBVERSION="Postgres $VPGDG"
			JBOSS_VERSION="not installed"
			IBPM_VERSION="not installed"
			AAVERSION="not installed"
			MAILVERSION="not installed"
			SSOFIVERSION="not installed"
			ALFRESCOVERSION="not installed"
			FLOWABLEVERSION="$VFLOWABLE"
			TOMCATVERSION="$VAPACHE"
			REAVERSION="not installed"
			DBINSTALLED="true"
			JBOSSINSTALLED="false"
			IBPMINSTALLED="false"
			ESINSTALLED="false"
			REAINSTALLED="false"
			NGINXINSTALLED="false"
			ALFRESCOINSTALLED="false"
			FLOWABLEINSTALLED="true"
			NGINXVERSION="not installed"
			BALVERSION="not installed"
		;;
		REA)
			DBVERSION="not installed"
			JBOSS_VERSION="not installed"
			IBPM_VERSION="not installed"
			AAVERSION="not installed"
			MAILVERSION="not installed"
			SSOFIVERSION="not installed"
			ALFRESCOVERSION="not installed"
			FLOWABLEVERSION="not installed"
			TOMCATVERSION="$VAPACHE"
			REAVERSION="unknown"
			DBINSTALLED="false"
			JBOSSINSTALLED="false"
			IBPMINSTALLED="false"
			ESINSTALLED="true"
			REAINSTALLED="true"
			NGINXINSTALLED="true"
			ALFRESCOINSTALLED="false"
			FLOWABLEINSTALLED="false"
			BALVERSION="not installed"
			nginx -v 2>$INSTALL_LOG_DIR/nginxversion
			NGINXVERSION=`cat $INSTALL_LOG_DIR/nginxversion|cut -f2 -d"/"`
		;;
	esac
	echo "{\"installdate\":\"$INSTALLDATE\",\"script\":\"$VERSION\",\"vmversion\":\"$VMVERSION\",\"osversion\":\"$OSRELEASE\",\"jdk8\":\"$VJDK8\",\"database\":\"$DBVERSION\",\"jboss\":\"$JBOSS_VERSION\",\"ibpm\":\"$IBPM_VERSION\",\"es\":\"$VELK\",\"chat\":\"$CHATVERSION\",\"aa\":\"$AAVERSION\",\"email\":\"$MAILVERSION\",\"ssofi\":\"$SSOFIVERSION\",\"ballib\":\"$BALVERSION\",\"alfresco\":\"$ALFRESCOVERSION\",\"flowable\":\"$FLOWABLEVERSION\",\"tomcat\":\"$TOMCATVERSION\",\"rea\":\"$REAVERSION\",\"nginx\":\"$NGINXVERSION\"}" >$APPVERSIONFILE
	echo "{\"database\":\"$DBINSTALLED\",\"jboss\":\"$JBOSSINSTALLED\",\"ibpm\":\"$IBPMINSTALLED\",\"es\":\"$ESINSTALLED\",\"rea\":\"$REAINSTALLED\",\"nginx\":\"$NGINXINSTALLED\",\"alfresco\":\"$ALFRESCOINSTALLED\",\"flowable\":\"$FLOWABLEINSTALLED\"}" >$APPINSTALLFILE
}

Cleanup_install()
{
# **************************************************************************************
# *                                                                                    *
# * This function will remove the installation directory and all its files if the      *
# * user wants to do so.                                                               *
# *                                                                                    *
# **************************************************************************************
	echo "*** Installation cleanup ***" >>$ERROR
	if [ -s $ERROR ]
	then
		Screen_output 0 "Errors did occur during the installation process. Please check the file $ERROR first before continuing."
		echo ""
		more $ERROR
	fi
	case "$APPLICATION" in
		IBPM)
			if [ "$ALFRESCO" = "true" ]
			then
				Wait_alfresco
			fi
		;;
		REA)
			curl -XGET "http://$NEWHOSTNAME:9200/_cluster/health?pretty" > $INSTALL_LOG_DIR/shardinfo 2>$ILOG
			sleep 2
			BADSHARDS=`grep "initializing_shards" $INSTALL_LOG_DIR/shardinfo | cut -f2 -d":" | cut -f2 -d" " | cut -f1 -d","`
			if [ "$BADSHARDS" -ne 0 ]
			then
				clear
				echo ""
				echo ""
				echo -n " Waiting for Elastic Search to initialize all shards ."
				while [ "$BADSHARDS" -ne 0 ]
				do
					curl -XGET "http://$NEWHOSTNAME:9200/_cluster/health?pretty" > $INSTALL_LOG_DIR/shardinfo 2>$ILOG
					sleep 30
					echo -n "."
					BADSHARDS=`grep "initializing_shards" $INSTALL_LOG_DIR/shardinfo | cut -f2 -d":" | cut -f2 -d" " | cut -f1 -d","`
				done
			fi
		;;
	esac
	cd $TARGET_DIR
	if [ "$CLEARLOG" = "true" ]
	then
		rm -rf $INSTALL_LOG_DIR
	fi
}

Restart_Jboss()
{
# **************************************************************************************
# *                                                                                    *
# * This function will restart JBoss.                                                  *
# *                                                                                    *
# **************************************************************************************
	echo "*** Restarting JBoss ***" >>$ERROR
	service jbossibpm stop >$ILOG 2>>$ERROR
	sleep 30
	service jbossibpm start > $ILOG 2>>$ERROR
	sleep 40
}

Wait_alfresco()
{
# **************************************************************************************
# *                                                                                    *
# * This function will wait until Alfresco has been initialized, before the            *
# * installation can move to the next step.                                            *
# *                                                                                    *
# **************************************************************************************	
	if [ ! -f $TARGET_DIR/alfresco-community/alfresco.log ]
	then
		touch $TARGET_DIR/alfresco-community/alfresco.log
	fi
	if ! grep "Startup of 'Transformers' subsystem, ID: " $TARGET_DIR/alfresco-community/alfresco.log | grep "complete" >$ILOG 2>>$ERROR
	then
		clear
		echo ""
		echo ""
		echo -n " Waiting for the Alfresco Database to finish initializing ."
		until grep "Startup of 'Transformers' subsystem, ID: " $TARGET_DIR/alfresco-community/alfresco.log | grep "complete" >$ILOG
		do
			sleep 15
			echo -n "."
		done
	fi
}

Last_reboot()
{
# **************************************************************************************
# *                                                                                    *
# * This function will reboot the VM at the end of the installation.                   *
# *                                                                                    *
# **************************************************************************************
	if [ "$REBOOTEND" = "true" ]
	then
		sleep 5
		reboot
	fi

}

Modify_posthoc()
{
# **************************************************************************************
# *                                                                                    *
# * This function will update the Config.properties file in the posthoc.war file       *
# * with the correct hostname.                                                         *
# *                                                                                    *
# **************************************************************************************
	cd $INSTALL_LOG_DIR
	cp $INSTALL_FILE_DIR/options/posthoc.war $INSTALL_LOG_DIR
	jar xvf $INSTALL_LOG_DIR/posthoc.war -x WEB-INF/Config.properties >$ILOG 2>>$ERROR
	jar xvf $INSTALL_LOG_DIR/posthoc.war -x WEB-INF/DataLocation.properties >$ILOG 2>>$ERROR
	sed -i -e "s/interstagedemo/$NEWHOSTNAME/g" WEB-INF/Config.properties 2>>$ERROR
	sed -i -e "s/127.0.0.1/$NEWHOSTNAME/g" WEB-INF/Config.properties 2>>$ERROR
	sed -i -e "s/c://g" WEB-INF/DataLocation.properties 2>>$ERROR
	jar uvf posthoc.war WEB-INF > $ILOG 2>>$ERROR
	cd $TARGET_DIR
}

Check_war()
{
# **************************************************************************************
# *                                                                                    *
# * This function checks war files for the existence of files as specified by the      *
# * second option.                                                                     *
# *                                                                                    *
# **************************************************************************************
	if jar tvf $1 | grep "$2" >$ILOG 2>>$ERROR
	then
		WARCONTENT="true"
	else
		WARCONTENT="false"
	fi
}

Change_smtp()
{
# **************************************************************************************
# *                                                                                    *
# * This function will change the I-BPM SMTP settings to use kMail by default.         *
# *                                                                                    *
# **************************************************************************************
	echo "*** Changing SMTP settings ***" >>$ERROR
	case "$IBPMDB" in
		oracle)
			sqlplus ibpmuser/Fujitsu1 @ $INSTALL_FILE_DIR/misc/smtphost.sql >$ILOG 2>>$ERROR
			ret=$?
		;;
		postgresas)
			$TARGET_DIR/edb/9.5AS/bin/psql -U enterprisedb -d ibpmdb -c "\copy ibpmproperties to '$INSTALL_LOG_DIR/bpmprop' csv;" >$ILOG 2>>$ERROR
			sed -i -e "s/SMTPServerHost,\"\",-1,0/SMTPServerHost,\"$NEWHOSTNAME\",-1,0/g" $INSTALL_LOG_DIR/bpmprop >$ILOG 2>>$ERROR
			sed -i -e 's/SMTPServerPort,25,-1,0/SMTPServerPort,2525,-1,0/g' $INSTALL_LOG_DIR/bpmprop >$ILOG 2>>$ERROR
			$TARGET_DIR/edb/9.5AS/bin/psql -U enterprisedb -d ibpmdb -c "delete from ibpmproperties" >$ILOG 2>>$ERROR
			$TARGET_DIR/edb/9.5AS/bin/psql -U enterprisedb -d ibpmdb -c "\copy ibpmproperties from '$INSTALL_LOG_DIR/bpmprop' csv;" >$ILOG 2>>$ERROR
			ret=$?
		;;
	esac
	if [ $ret -ne 0 ]
	then
		Screen_output 0 "The SMTP host setting did not get changed !!"
		echo ""
		echo " The errorcode is : $ret"
		echo ""
		Continue
	fi
}

Install_dxpcommunity()
{
	if [ ! -f $INSTALL_LOG_DIR/postgresinstalled.log ]
	then
		sed -i -e 's/Installing Database ......................... Waiting/Installing Database ......................... Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
		Install_postgres
		sed -i -e 's/Installing Database ......................... Running/Installing Database ......................... Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
	fi
	if [ ! -f $INSTALL_LOG_DIR/flowable.log ]
	then
		sed -i -e 's/Installing Flowable ......................... Waiting/Installing Flowable ......................... Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
		Install_flowable
		sed -i -e 's/Installing Flowable ......................... Running/Installing Flowable ......................... Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
	fi
	if [ ! -f $INSTALL_LOG_DIR/tomcat.log ]
	then
		sed -i -e 's/Installing Tomcat ........................... Waiting/Installing Tomcat ........................... Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
		Install_tomcat
		sed -i -e 's/Installing Tomcat ........................... Running/Installing Tomcat ........................... Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
	fi
	if [ ! -f $INSTALL_LOG_DIR/flowablewars.log ]
	then
		sed -i -e 's/Installing war files for Flowable ........... Waiting/Installing war files for Flowable ........... Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
		Install_flowable_wars
		sed -i -e 's/Installing war files for Flowable ........... Running/Installing war files for Flowable ........... Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
	fi
	if [ ! -f $INSTALL_LOG_DIR/tomcatstart.log ]
	then
		sed -i -e 's/Starting Tomcat ............................. Waiting/Starting Tomcat ............................. Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
		Start_tomcat
		sleep 120
		sed -i -e 's/Starting Tomcat ............................. Running/Starting Tomcat ............................. Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
	fi
}

Install_es()
{
	if [ ! -f $INSTALL_LOG_DIR/elasticsearch.log ]
	then
		sed -i -e 's/Installing Elastic Search ................... Waiting/Installing Elastic Search ................... Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
		Install_elastic
		sed -i -e 's/Installing Elastic Search ................... Running/Installing Elastic Search ................... Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
	fi
	if [ ! -f $INSTALL_LOG_DIR/esgui.log ]
	then
		sed -i -e 's/Installing E.S. GUI ......................... Waiting/Installing E.S. GUI ......................... Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
		Install_esgui
		sed -i -e 's/Installing E.S. GUI ......................... Running/Installing E.S. GUI ......................... Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
	fi
}

Screen_output()
{
# **************************************************************************************
# *                                                                                    *
# * This function will post a remark or question to the user. If the first argument is *
# * a '0', it will be considered a remark, if it is a '1', it will be a question.      *
# * The second argument is the text for the remark / question. The variable $INPUT     *
# * will be returned in case of a question to the calling function.                    *
# *                                                                                    *
# **************************************************************************************
	if [ $1 = 0 ]
	then
		clear
		echo ""
		echo " *************************************************************************************************************************************"
	fi
	echo ""
	if [ $1 = 1 ]
	then
		echo -n " $2"
		read INPUT
	else
		echo " $2"
	fi
	if [ $1 = 0 ]
	then
		echo ""
		echo " *************************************************************************************************************************************"
		echo ""
	fi
}

Continue()
{
# **************************************************************************************
# *                                                                                    *
# * This function will ask the user if they want to continue running the installation  *
# * or abort.                                                                          *
# *                                                                                    *
# **************************************************************************************
	Screen_output 1 "Do you want to continue (y/n) ? [y] : "
	if [ "$INPUT" = "" -o "$INPUT" = "y" ]
	then
		return
	else
		Abort_install
	fi
}

Abort_install()
{
# **************************************************************************************
# *                                                                                    *
# * This function gets called when the installation needs to be aborted due to a       *
# * critical error.                                                                    *
# *                                                                                    *
# **************************************************************************************
	echo "** Aborting the installation **" >> $ERROR
	echo ""
	echo ""
	echo " Please correct / complete the step(s) shown above and restart the installation."
	if [ -s $ERROR ]
	then
		echo ""
		echo " You may want to check the file $ERROR as well."
	fi
	Press_enter
	touch $INSTALL_LOG_DIR/abort.log
	exit 1
}

Press_enter()
{
# **************************************************************************************
# *                                                                                    *
# * This function waits until the Enter key has been pressed.                          *
# *                                                                                    *
# **************************************************************************************
	Screen_output 1 "Please press ENTER to continue .... : "
}

Paint_screen()
{
# **************************************************************************************
# *                                                                                    *
# * This function updates the installation status screen.                              *
# *                                                                                    *
# **************************************************************************************
	clear
	if [ ! -f $INSTALL_LOG_DIR/reboot.log ]
	then
		cat $PREINSTSCREEN
	else
		case "$APPLICATION" in
			IBPM)
				if [ "$COMBOINSTALL" = "false" ]
				then
					BANNER="Interstage BPM (DXP Enterprise)"
				else
					BANNER="Interstage BPM (DXP Enterprise+)"
				fi
			;;
			FLOWABLE)
				BANNER="Flowable (DXP Community)"
			;;
			REA)
				BANNER="REA (DXP Lite)"
			;;
		esac
		Show_banner
		cat $INSTSCREEN
	fi
}

Create_screens()
{
	if [ ! -f $PREINSTSCREEN ]
	then
		echo " *********************************************************************************************" > $PREINSTSCREEN
		echo "" >> $PREINSTSCREEN
		echo " The pre-installation tasks are in progress.">> $PREINSTSCREEN
		echo "">> $PREINSTSCREEN
		echo " *********************************************************************************************">> $PREINSTSCREEN
		echo "">> $PREINSTSCREEN
		echo "">> $PREINSTSCREEN
		if [ "$ALFRESCO" = "true" ]
		then
			echo "	Checking system resources ................... Waiting">> $PREINSTSCREEN
		fi
		echo "	Checking existence of installation files ..... Waiting">> $PREINSTSCREEN
		echo "	Changing O.S. settings ....................... Waiting">> $PREINSTSCREEN
		echo "	Installing auto start scripts ................ Waiting">> $PREINSTSCREEN
		if [ "$DEMOVM" = "true" ]
		then
			echo "	Resetting the root password .................. Waiting">> $PREINSTSCREEN
		else
			echo "	Resetting the root password .................. Skipping">> $PREINSTSCREEN
		fi
		echo "	System reboot ................................ Waiting">> $PREINSTSCREEN
	fi
	if [ ! -f $INSTSCREEN ]
	then
		echo "	Checking O.S Tools .......................... Waiting" > $INSTSCREEN
		echo "	Installing JDK8 ............................. Waiting" >> $INSTSCREEN
		echo "	Installing VM web site ...................... Waiting" >> $INSTSCREEN
		echo "	Installing Chat ............................. Waiting" >> $INSTSCREEN
		case "$APPLICATION" in
			IBPM)
				echo "	Installing DXP Database ..................... Waiting" >> $INSTSCREEN
				if [ "$INSTALLJBOSS" = "true" ]
				then
					echo "	Installing JBoss ............................ Waiting" >> $INSTSCREEN
					echo "	Installing Patches for JBoss ................ Waiting" >> $INSTSCREEN
					echo "	Starting JBoss .............................. Waiting" >> $INSTSCREEN
					echo "	Configuring JBoss ........................... Waiting" >> $INSTSCREEN
					if [ "$INSTALLIBPM" = "true" ]
					then
						echo "	Unzipping IBPM engine folder ................ Waiting" >> $INSTSCREEN
						echo "	Configuring IBPM pre-installation ........... Waiting" >> $INSTSCREEN
						echo "	Installing IBPM ............................. Waiting" >> $INSTSCREEN
						echo "	Installing BPM Action Library ............... Waiting" >> $INSTSCREEN
					else
						echo "	Unzipping IBPM engine folder ................ Skipping" >> $INSTSCREEN
						echo "	Configuring IBPM pre-installation ........... Skipping" >> $INSTSCREEN
						echo "	Installing IBPM ............................. Skipping" >> $INSTSCREEN
						echo "	Installing BPM Action Library ............... Skipping" >> $INSTSCREEN
					fi
					echo "	Installing war files ........................ Waiting" >> $INSTSCREEN
				else
					echo "	Installing JBoss ............................ Skipping" >> $INSTSCREEN
					echo "	Installing JBoss Patches .................... Skipping" >> $INSTSCREEN
					echo "	Starting JBoss .............................. Skipping" >> $INSTSCREEN
					echo "	Configuring JBoss ........................... Skipping" >> $INSTSCREEN
					echo "	Unzipping IBPM engine folder ................ Skipping" >> $INSTSCREEN
					echo "	Configuring IBPM pre-installation ........... Skipping" >> $INSTSCREEN
					echo "	Installing IBPM ............................. Skipping" >> $INSTSCREEN
					echo "	Installing BPM Action Library ............... Skipping" >> $INSTSCREEN
					echo "	Installing war files ........................ Skipping" >> $INSTSCREEN
				fi
				if [ "$ALFRESCO" = "true" ]
				then
					echo "	Installing Alfresco ......................... Waiting" >> $INSTSCREEN
				else
					echo "	Installing Alfresco ......................... Skipping" >> $INSTSCREEN
				fi
				echo "	Installing Elastic Search ................... Waiting" >> $INSTSCREEN
				echo "	Installing E.S. GUI ......................... Waiting" >> $INSTSCREEN
				if [ "$COMBOINSTALL" = "true" ]
				then
					echo "	Installing Database ......................... Waiting" >> $INSTSCREEN
					echo "	Installing Flowable ......................... Waiting" >> $INSTSCREEN
					echo "	Installing Tomcat ........................... Waiting" >> $INSTSCREEN
					echo "	Installing war files for Flowable ........... Waiting" >> $INSTSCREEN
					echo "	Starting Tomcat ............................. Waiting" >> $INSTSCREEN
				fi
			;;
			FLOWABLE)
				echo "	Installing Database ......................... Waiting" >> $INSTSCREEN
				echo "	Installing Flowable ......................... Waiting" >> $INSTSCREEN
				echo "	Installing Tomcat ........................... Waiting" >> $INSTSCREEN
				echo "	Installing war files for Flowable ........... Waiting" >> $INSTSCREEN
				echo "	Starting Tomcat ............................. Waiting" >> $INSTSCREEN
			;;
			REA)
			echo "	Installing Elastic Search ................... Waiting" >> $INSTSCREEN
			echo "	Installing E.S. GUI ......................... Waiting" >> $INSTSCREEN
			echo "	Installing REA .............................. Waiting" >> $INSTSCREEN
			;;
		esac
		echo "	Creating App. version files ................. Waiting" >> $INSTSCREEN
		if [ "$CLEARLOG" = "true" ]
		then
			echo "	Deleting Installation files ................. Waiting" >> $INSTSCREEN
		else
			echo "	Deleting Installation files ................. Skipping" >> $INSTSCREEN
		fi
		if [ "$REBOOTEND" = "true" ]
		then
			echo "	Final System reboot ......................... Waiting" >> $INSTSCREEN
		else
			echo "	Final System reboot ......................... Skipping" >> $INSTSCREEN
		fi
	fi
}

Show_banner()
{
# **************************************************************************************
# *                                                                                    *
# * This function shows the banner during the installation.                            *
# *                                                                                    *
# **************************************************************************************
	echo " *********************************************************************************************"
	echo ""
	echo " $BANNER installation is in progress."
	echo ""
	echo " *********************************************************************************************"
	echo ""
	echo ""
}

Main()
{
# **************************************************************************************
# *                                                                                    *
# * This is the main function of this installation script. This function calls all     *
# * other function to install the product(s).                                          *
# *                                                                                    *
# **************************************************************************************
	clear
	
# **** Check for root user ****

	Install_user_check
	
# **** Script initialization ****

	Init
	
# **** Initial Welcome screen ****

	if [ ! -f $TARGET_DIR/logs/welcome.log ]
	then
		Welcome
	else
		INSTALL_LOG_DIR=$TARGET_DIR/logs
		ILOG=$INSTALL_LOG_DIR/ilog.log
		ERROR=$INSTALL_LOG_DIR/install-error.log
		NEWHOSTNAME=`hostname`
		if [ -f $INSTALL_LOG_DIR/abort.log ]
		then
			echo "** Restart after abort **" >> $ERROR
			REASON="restart of the installation."
			rm -rf $INSTALL_LOG_DIR/abort.log
		else
			echo "** Restart after reboot **" >> $ERROR
			REASON="reboot of the server / VM."
		fi
		Screen_output 0 "The Installation process will continue where it stopped before the $REASON."
		echo ""
	fi
	
	PREINSTSCREEN=$INSTALL_LOG_DIR/preinstscreen
	INSTSCREEN=$INSTALL_LOG_DIR/instscreen
	Create_screens
	
# **** System resource check for Alfresco only ****

	if [ "$ALFRESCO" = "true" ]
	then
		sed -i -e 's/Checking system resources ................... Waiting/Checking system resources ................... Running/g' $PREINSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
		Resource_check
		sed -i -e 's/Checking system resources ................... Running/Checking system resources ................... Completed/g' $PREINSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
	fi
	
# **** Check for existence of all installation files ****
	sed -i -e 's/Checking existence of installation files ..... Waiting/Checking existence of installation files ..... Running/g' $PREINSTSCREEN >$ILOG 2>>$ERROR
	Paint_screen
	Check_install_files
	sed -i -e 's/Checking existence of installation files ..... Running/Checking existence of installation files ..... Completed/g' $PREINSTSCREEN >$ILOG 2>>$ERROR
	Paint_screen
	
# **** Complete O.S. changes ****

	if [ ! -f $INSTALL_LOG_DIR/oschange.log ]
	then
		sed -i -e 's/Changing O.S. settings ....................... Waiting/Changing O.S. settings ....................... Running/g' $PREINSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
		Change_os_settings
		sed -i -e 's/Changing O.S. settings ....................... Running/Changing O.S. settings ....................... Completed/g' $PREINSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
	fi
	
# **** Create / Install auto start script + VM Welcome screen ****

	if [ ! -f $INSTALL_LOG_DIR/scriptinstall.log ]
	then
		sed -i -e 's/Installing auto start scripts ................ Waiting/Installing auto start scripts ................ Running/g' $PREINSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
		Install_scripts
		sed -i -e 's/Installing auto start scripts ................ Running/Installing auto start scripts ................ Completed/g' $PREINSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
	fi
	
# **** Resetting the root password for the demo VM ****
	
	if [ ! -f $INSTALL_LOG_DIR/rootpwreset.log ]
	then
		if [ "$DEMOVM" = "true" ]
		then
			sed -i -e 's/Resetting the root password .................. Waiting/Resetting the root password .................. Running/g' $PREINSTSCREEN >$ILOG 2>>$ERROR
			Paint_screen
			Reset_rootpw
			sed -i -e 's/Resetting the root password .................. Running/Resetting the root password .................. Completed/g' $PREINSTSCREEN >$ILOG 2>>$ERROR
			Paint_screen
		fi
	fi
	
# **** System reboot after initial setup ****
	
	if [ ! -f $INSTALL_LOG_DIR/reboot.log ]
	then
		sed -i -e 's/System reboot ................................ Waiting/System reboot ................................ Triggered/g' $PREINSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
		sleep 5
		touch $INSTALL_LOG_DIR/reboot.log
		reboot
	fi
	
# **** Checking for O.S. tools and updates ****
	sed -i -e 's/Checking O.S Tools .......................... Waiting/Checking O.S Tools .......................... Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
	Paint_screen
	Check_tools
	sed -i -e 's/Checking O.S Tools .......................... Running/Checking O.S Tools .......................... Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
	Paint_screen
	
# **** Installing JDK ****

	if [ ! -f $INSTALL_LOG_DIR/jdkinstalled.log ]
	then
		sed -i -e 's/Installing JDK8 ............................. Waiting/Installing JDK8 ............................. Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
		Install_jdk
		sed -i -e 's/Installing JDK8 ............................. Running/Installing JDK8 ............................. Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
	fi
	
# **** Installing the VM Web page ****

	if [ ! -f $INSTALL_LOG_DIR/webpage.log ]
	then
		sed -i -e 's/Installing VM web site ...................... Waiting/Installing VM web site ...................... Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
		Install_webpage
		sed -i -e 's/Installing VM web site ...................... Running/Installing VM web site ...................... Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
	fi
	
# **** Installing the Chat client ****
	
	if [ ! -f $INSTALL_LOG_DIR/chat.log ]
	then
		sed -i -e 's/Installing Chat ............................. Waiting/Installing Chat ............................. Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
		Install_chat
		sed -i -e 's/Installing Chat ............................. Running/Installing Chat ............................. Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
	fi
	
# **** The application specific installation of software starts below ****

	case "$APPLICATION" in
		IBPM)
		sed -i -e 's/Installing DXP Database ..................... Waiting/Installing DXP Database ..................... Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
		if [ "$IBPMDB" = "oracle" ]
		then
			if [ ! -f $INSTALL_LOG_DIR/oracleinstalled.log ]
			then
				Install_oracle
			fi 
		else
			if [ ! -f $INSTALL_LOG_DIR/postgresasinstalled.log ]
			then
				Install_postgresas
			fi
		fi
		sed -i -e 's/Installing DXP Database ..................... Running/Installing DXP Database ..................... Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
		Paint_screen
		if [ "$INSTALLJBOSS" = "true" ]
		then
			if [ ! -f $INSTALL_LOG_DIR/jboss.log ]
			then
				sed -i -e 's/Installing JBoss ............................ Waiting/Installing JBoss ............................ Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
				Install_jboss
				sed -i -e 's/Installing JBoss ............................ Running/Installing JBoss ............................ Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
			fi
			if [ ! -f $INSTALL_LOG_DIR/jbosspatches.log ]
				then
					sed -i -e 's/Installing Patches for JBoss ................ Waiting/Installing Patches for JBoss ................ Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
					Paint_screen
					PNUM=1
					for patch in `ls $INSTALL_FILE_DIR/software/Patch/jboss-eap-6/jboss-eap-6.4.?.CP.zip`
					do
						if [ ! -f $INSTALL_LOG_DIR/jbosspatch$PNUM ]
						then
							$TARGET_DIR/jboss-eap-6.4/bin/jboss-cli.sh --command="patch apply $patch" >$ILOG 2>>$ERROR
							ret=$?
							if [ $ret -ne 0 ]
							then
								Screen_output 0 " JBoss patch $patch failed to install !!"
								Continue
							else
								touch $INSTALL_LOG_DIR/jbosspatch$PNUM
								PNUM=`expr $PNUM + 1`
							fi
						fi
					done	
					if [ ! -f $INSTALL_LOG_DIR/jbosspatchBZ1358913 ]
					then
						$TARGET_DIR/jboss-eap-6.4/bin/jboss-cli.sh --command="patch apply $INSTALL_FILE_DIR/software/Patch/BZ-1358913.zip" >$ILOG 2>>$ERROR
						ret=$?
						if [ $ret -ne 0 ]
						then
							Screen_output 0 " JBoss patch BZ-1358913 failed to install !!"
							Continue
						else
							touch $INSTALL_LOG_DIR/jbosspatchBZ1358913
						fi
					fi
					touch $INSTALL_LOG_DIR/jbosspatches.log
					sed -i -e 's/Installing Patches for JBoss ................ Running/Installing Patches for JBoss ................ Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
					Paint_screen
			fi
			if [ ! -f $INSTALL_LOG_DIR/jbossstart.log ]
			then
				sed -i -e 's/Starting JBoss .............................. Waiting/Starting JBoss .............................. Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
				Jboss_startup
				sed -i -e 's/Starting JBoss .............................. Running/Starting JBoss .............................. Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
			fi
			if [ ! -f $INSTALL_LOG_DIR/jdbcconfig.log ]
			then
				sed -i -e 's/Configuring JBoss ........................... Waiting/Configuring JBoss ........................... Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
				Jdbc_config
				sed -i -e 's/Configuring JBoss ........................... Running/Configuring JBoss ........................... Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
			fi
		fi
		if [ "$INSTALLJBOSS" = "true" ] && [ "$INSTALLIBPM" = "true" ]
		then
			if [ ! -f $INSTALL_LOG_DIR/engineconfig.log ]
			then
				sed -i -e 's/Unzipping IBPM engine folder ................ Waiting/Unzipping IBPM engine folder ................ Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
				Ibpm_engine
				sed -i -e 's/Unzipping IBPM engine folder ................ Running/Unzipping IBPM engine folder ................ Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
			fi
			if [ ! -f $INSTALL_LOG_DIR/setupconfig.log ]
			then
				sed -i -e 's/Configuring IBPM pre-installation ........... Waiting/Configuring IBPM pre-installation ........... Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
				Setup_config
				sed -i -e 's/Configuring IBPM pre-installation ........... Running/Configuring IBPM pre-installation ........... Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
			fi
			if [ ! -f $INSTALL_LOG_DIR/ibpminstalled.log ]
			then
				sed -i -e 's/Installing IBPM ............................. Waiting/Installing IBPM ............................. Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
				Install_ibpm
				sed -i -e 's/Installing IBPM ............................. Running/Installing IBPM ............................. Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
			fi
			if [ ! -f $INSTALL_LOG_DIR/bpmaction.log ]
			then
				sed -i -e 's/Installing BPM Action Library ............... Waiting/Installing BPM Action Library ............... Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
				Install_bpmaction
				sed -i -e 's/Installing BPM Action Library ............... Running/Installing BPM Action Library ............... Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
			fi
			if [ ! -f $INSTALL_LOG_DIR/warinstalled.log ]
			then
				sed -i -e 's/Installing war files ........................ Waiting/Installing war files ........................ Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
				Install_war
				sed -i -e 's/Installing war files ........................ Running/Installing war files ........................ Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
			fi
		fi
		if [ "$ALFRESCO" = "true" ]
		then
			if [ ! -f $INSTALL_LOG_DIR/alfresco.log ]
			then
				sed -i -e 's/Installing Alfresco ......................... Waiting/Installing Alfresco ......................... Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
				Install_alfresco
				sed -i -e 's/Installing Alfresco ......................... Running/Installing Alfresco ......................... Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
			fi
		fi
		Install_es
		if [ -f $INSTALL_DIR/AgileAdapterData/Analytics.properties ]
		then
			sed -i -e "s/polling_in_seconds: 30/polling_in_seconds: 0/g" $TARGET_DIR/AgileAdapterData/Analytics.properties
		fi
		if [ "$COMBOINSTALL" = "true" ]
		then
			APPLICATION="FLOWABLE"
			Check_install_files
			Install_dxpcommunity
			APPLICATION="IBPM"
		fi
		;;
		FLOWABLE)
			Install_dxpcommunity
		;;
		REA)
			Install_es
			if [ ! -f $INSTALL_LOG_DIR/rea.log ]
			then
				sed -i -e 's/Installing REA .............................. Waiting/Installing REA .............................. Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
				Install_rea
				sed -i -e 's/Installing REA .............................. Running/Installing REA .............................. Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
				Paint_screen
			fi
		;;
	esac
	sed -i -e 's/Creating App. version files ................. Waiting/Creating App. version files ................. Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
	Paint_screen
	Create_appversion
	sed -i -e 's/Creating App. version files ................. Running/Creating App. version files ................. Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
	Paint_screen
	sed -i -e 's/Deleting Installation files ................. Waiting/Deleting Installation files ................. Running/g' $INSTSCREEN >$ILOG 2>>$ERROR
	Paint_screen
	Cleanup_install
	sed -i -e 's/Deleting Installation files ................. Running/Deleting Installation files ................. Completed/g' $INSTSCREEN >$ILOG 2>>$ERROR
	Paint_screen
	sed -i -e 's/Final System reboot ......................... Waiting/Final System reboot ......................... Triggered/g' $INSTSCREEN >$ILOG 2>>$ERROR
	Paint_screen
	Last_reboot
}

Main