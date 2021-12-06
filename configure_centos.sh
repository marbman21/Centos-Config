#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGFILE="/var/log/configure_linux.log"

if [ ! -f /etc/redhat-release ]; then
	echo "CentOS not detected, aborting."
	exit 0
fi

echo "Updating OS..."
yum update -y
yum groupinstall "Base" --skip-broken -y
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
/usr/sbin/setenforce 0
iptables-save > /root/firewall.rules


echo "Configuring SSH..."
sed -i 's/#UseDNS.*/UseDNS no/' /etc/ssh/sshd_config

echo "Configuring SSD (if owning)..."
for DEVFULL in /dev/sg? /dev/sd?; do
	DEV=$(echo "$DEVFULL" | cut -d'/' -f3)
        if [ -f "/sys/block/$DEV/queue/rotational" ]; then
        	TYPE=$(grep "0" /sys/block/$DEV/queue/rotational > /dev/null && echo "SSD" || echo "HDD")
		if [ "$TYPE" = "SSD" ]; then
			systemctl enable fstrim.timer

		fi
        fi
done

echo "Installing CRON clean from Journal..."
echo "30 22 * * * root /usr/bin/journalctl --vacuum-time=1d; /usr/sbin/service systemd-journald restart" > /etc/cron.d/clean_journal
service crond restart

# POST-INSTALLATION TASKS

for i in "$@"
do
case $i in
        --notify-email=*)
                EMAIL="${i#*=}"
		echo "Avisando a $1..."
	         cat "$LOGFILE" | sed ':a;N;$!ba;s/\n/<br>\n/g' | mailx -s "Servidor $(hostname -f) configurado con $(basename $0) $(echo -e "\nContent-Type: text/html")" -r "$(hostname -f) <$(hostname -f)>" "$EMAIL"
	;;
esac
done

echo "Finalized!"
