#!/bin/bash

Init()
{
	MOUNTFS=/opt
	SHAREFILE=/root/.shareinfo
}

Get_info()
{
	clear
	if [ -f /root/.shareinfo ]
	then
		source $SHAREFILE
	else
		echo ""
		echo -n " Enter the hostname of your Windows host : "
		read HOST
		echo ""
		echo -n " Enter the name of the Windows share : "
		read SHARENAME
		echo ""
		echo -n " Enter the name of the local Windows user : "
		read WUSER
		echo "HOST=\"$HOST\"" > $SHAREFILE
		echo "SHARENAME=\"$SHARENAME\"" >> $SHAREFILE
		echo "WUSER=\"$WUSER\"" >> $SHAREFILE
		echo "export HOST SHARENAME WUSER" >>$SHAREFILE
		chmod 755 $SHAREFILE
	fi
	MOUNTPOINT=$MOUNTFS/$SHARENAME
	echo ""
	echo -n " Enter the password for user $WUSER : "
	read PASSWD
	echo ""
}

Mount_share()
{
	if [ ! -d $MOUNTPOINT ]
	then
		mkdir -p $MOUNTPOINT 2>/dev/null
		chmod 777 $MOUNTPOINT 2>/dev/null
	fi
	yum -y install cifs-utils >/dev/null 2>&1
	echo " The software is being installed and the share is being mounted. This may take a minute ...."
	mount.cifs \\\\$HOST\\$SHARENAME $MOUNTPOINT -o user=$WUSER,pass="$PASSWD" >/dev/null 2>&1
	ret=$?
	if [ $ret -ne 0 ]
	then
		clear
		echo ""
		echo " Mount of share $SHARENAME failed !!!"
		echo ""
		if [ -f $SHAREFILE ]
		then
			rm -rf $SHAREFILE
		fi
	else
		clear
		echo ""
		echo " Your share $SHARENAME has been mounted to $MOUNTPOINT"
		echo ""
	fi
}

Main()
{
	Init
	Get_info
	Mount_share
}

Main
