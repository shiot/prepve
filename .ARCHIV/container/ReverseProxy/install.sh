#!/bin/bash
{

  # Container Configuration
  # $1=ctTemplate (ubuntu/debian/turnkey-openvpn) - $2=hostname - $3=ContainerRootPasswort - $4=hdd size - $5=cpu cores - $6=RAM Swap/2 - $7=unprivileged 0/1 - $8=features (keyctl=1,nesting=1,mount=cifs)
  lxcSetup ubuntu $ctName 4 1 512 1 "keyctl=1,nesting=1"

  # Comes from Mainscript - start.sh --> Function lxcSetup
  ctID=$(pct list | grep ${ctName} | awk $'{print $1}')

  # Software that must be installed on the container
  # example - containerSoftware="docker.io docker-compose"
  containerSoftware="docker.io docker-compose"

  # Start Container, because Container stoped aftrer creation
  pct start $ctID
  sleep 10

  # echo [INFO] The container "CONTAINERNAME" is prepared for configuration
  echo -e "XXX\n55\n${lng_lxc_create_text_software_install}\nXXX"

  # Install the packages specified as containerSoftware
  for package in $containerSoftware; do
    pct exec $nextCTID -- bash -c "apt-get install -y $package > /dev/null 2>&1"
  done

  # Execute commands on containers
  echo -e "XXX\n59\n${lng_lxc_create_text_package_install} - \"NGINX Proxy Manager\"\nXXX"
  pct exec $ctID -- bash -ci "systemctl start docker && systemctl enable docker > /dev/null 2>&1"
  pct exec $ctID -- bash -ci "mkdir -p /root/npm"
  pct exec $ctID -- bash -ci "wget -qO /root/npm/config.json $rawGitHubURL/container/$ctName/config.json"
  pct exec $ctID -- bash -ci "wget -qO /root/npm/docker-compose.yml $rawGitHubURL/container/$ctName/docker-compose.yml"
  pct exec $ctID -- bash -ci "sed -i 's+ROOTPASSWORDTOCHANGE+$ctRootpw+g' /root/npm/config.json"
  pct exec $ctID -- bash -ci "sed -i 's+ROOTPASSWORDTOCHANGE+$ctRootpw+g' /root/npm/docker-compose.yml"
  pct exec $ctID -- bash -ci "cd npm && docker-compose up -d --quiet-pull > /dev/null 2>&1"

  # Container description in the Proxmox web interface
  pct set $ctID --description $'Shell Login\nBenutzer: root\nPasswort: '"$ctRootpw"$'\n\nWebGUI\nAdresse: http://'"$nextCTIP"$':81\nBenutzer: admin@example.com\nPasswort: changeme'

  # echo [INFO] Create firewall rules for container "CONTAINERNAME"
  echo -e "XXX\n99\n${lng_lxc_create_text_firewall}\nXXX"

  # Create Firewallgroup - If a port should only be accessible from the local network - IN ACCEPT -source +network -p tcp -dport PORTNUMBER -log nolog
  echo -e "[group $(echo $ctName|tr "[:upper:]" "[:lower:]")]\n\nIN HTTPS(ACCEPT) -log nolog\nIN HTTP(ACCEPT) -log nolog\nIN ACCEPT -source +network -p tcp -dport 81 -log nolog # Weboberfläche\n\n" >> $clusterfileFW

  # Allow Firewallgroup
  echo -e "[OPTIONS]\n\nenable: 1\n\n[RULES]\n\nGROUP $(echo $ctName|tr "[:upper:]" "[:lower:]")" > /etc/pve/firewall/$ctID.fw

  # Graphical installation progress display
} | whiptail --backtitle "© 2021 - SmartHome-IoT.net - ${lng_lxc_setup}" --title "${lng_lxc_create_title} - $ctName" --gauge "${lng_lxc_setup_text}" 6 60 0