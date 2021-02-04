#!/bin/bash

osUbuntu="ubuntu-20.04"         # Container Template für Ubuntu v20.04
osUbuntu18="ubuntu-18.04"       # Container Template für Ubuntu v18.04
osDebian="debian-10-standard"   # Container Template für Debian v10

##################### Script Variables #####################

# Colorize the Shell
ok="[\e[1;32mOK\e[0m]   "
info="[\e[1;33mINFO\e[0m] "
error="[\e[1;31mERROR\e[0m]"
question="[\e[1;34mFRAGE\e[0m]"
yesno="\e[1;34mJ\e[0m = Ja oder \e[1;34mN\e[0m = Nein:"
tick="[\e[1;32m✓\e[0m]"
cross="[\e[1;31m✗\e[0m]"
line="[\e[1;33m-\e[0m]"

# Divide by two so the dialogs take up half of the screen, which looks nice.
r=$(( rows / 2 ))
c=$(( columns / 2 ))
# Unless the screen is tiny
r=$(( r < 20 ? 20 : r ))
c=$(( c < 70 ? 70 : c ))

# Variables are needed for calculations in the script
gatewayIP=$(ip r | grep default | cut -d" " -f3)
pveIP=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | cut -d/ -f1)
cidr=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | cut -d/ -f2)
networkIP=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | cut -d/ -f1 | cut -d. -f1,2,3)
rootDisk=$(lsblk -oMOUNTPOINT,PKNAME -P | grep 'MOUNTPOINT="/"' | cut -d' ' -f2 | cut -d\" -f2 | sed 's#[0-9]*$##')
otherDisks=$(lsblk -nd --output NAME | sed "s#$rootDisk##" | sed ':M;N;$!bM;s#\n# #' | sed 's# s#s#g' | sed 's# h#h#g' | sed ':M;N;$!bM;s#\n# #g')
ctIDall=$(pct list | tail -n +2 | awk '{print $1}')
downloadPath="local"
ctStandardsoftware="curl wget software-properties-common gnupg2 net-tools"
rawGitHubURL="https://raw.githubusercontent.com/shiot/prepve/master"
. /etc/os-release
osname=$VERSION_CODENAME

##################### Functions #####################

function shellLogo() {
  echo "                                                                                                                                                   "
  echo "                                                                                                                                                   "
  echo " .d8888b.                                 888    888    888                                      8888888     88888888888                    888    "
  echo "d88P  Y88b                                888    888    888                                        888           888                        888    "
  echo "Y88b.                                     888    888    888                                        888           888                        888    "
  echo " 'Y888b.   88888b.d88b.   8888b.  888d888 888888 8888888888  .d88b.  88888b.d88b.   .d88b.         888   .d88b.  888      88888b.   .d88b.  888888 "
  echo "    'Y88b. 888 '888 '88b     '88b 888P'   888    888    888 d88''88b 888 '888 '88b d8P  Y8b        888  d88''88b 888      888 '88b d8P  Y8b 888    "
  echo "      '888 888  888  888 .d888888 888     888    888    888 888  888 888  888  888 88888888 888888 888  888  888 888      888  888 88888888 888    "
  echo "Y88b  d88P 888  888  888 888  888 888     Y88b.  888    888 Y88..88P 888  888  888 Y8b.            888  Y88..88P 888  d8b 888  888 Y8b.     Y88b.  "
  echo " 'Y8888P'  888  888  888 'Y888888 888      'Y888 888    888  'Y88P'  888  888  888  'Y8888       8888888 'Y88P'  888  Y8P 888  888  'Y8888   'Y888 "
  echo "                                                                                                                                                   "
  echo "                                                                                                                                                   "
}

function shellStart() {
  clear
  shellLogo
  echo "################################ copyright SmartHome - IoT - 2021 ##################################"
  echo "#                                                                                                  #"
  echo "# Ich empfehle Proxmox auf einer SSD zu installieren, 128GB reichen völlig aus. Für Festplatten    #"
  echo "# von virtuellen Maschinen und Containern empfehle ich eine zweite SSD. Diese SSD sollte mit einer #"
  echo "# größe von 128GB - 512GB (je nach nutzung von Containern und virtuellen Maschinen ausreichen.     #"
  echo "# Natürlich kann in Proxmox auch ein Raid als Medien/Dokumentenfestplatte eingerichtet werden,     #"
  echo "# dies würde ich allerdings nicht empfehlen. Nutze hierfür eine NAS (QNap, Synology, o. ä.).       #"
  echo "# Wenn ein Raid/ZFS-Pool für diesen Zweck verwendet werden soll, musst die deinen Server mit ge-   #"
  echo "# nügend Arbeitsspeicher ausstatten. Als Faustformel gilt 1GB RAM pro 1TB Festplattenkapazität.    #"
  echo "#                                                                                                  #"
  echo "####################################################################################################"
  echo ""
  echo ""
  read -p "$(echo -e "$question") Ich habe den Text gelesen, zur Kenntnis genommen und bin damit einverstanden. $(echo -e "$yesno") " -rn1 && echo ""
  if [[ $REPLY =~ ^[JjYy]$ ]]; then
    clear
    shellLogo
    echo -e "##################### Rechtliche Hinweise / \e[1;30mLegal notice\e[0m - Deutsch / \e[1;30mGerman\e[0m ######################"
    echo "#                                                                                                #"
    echo "# Ein Skript, welches schnell und einfach die ersten wichtigsten Konfigurationen von Proxmox VE  #"
    echo "# übernimmt. Nach der Ausführung dieses Skripts sind E-Mailbenachrichtigungen, Firewall          #"
    echo "# Einstellungen, Backups und evtl. ZFS-Pools in Proxmox VE eingerichtet. Außerdem werden einige  #"
    echo "# Container (CT) / virtuelle Maschinen (VM) eingerichtet. Ziel ist es Neulingen den einstieg     #"
    echo "# in Proxmox VE zu erleichtern und schnell einen ""sicheren"" Homeserver an die Hand zu geben.   #"
    echo "#                                                                                                #"
    echo -e "# \e[1;35mHAFTUNGSAUSSCHLUSS\e[0m                                                                             #"
    echo "# Ich gehe davon aus, dass Du weisst was Du tust, und es sich um ein neu installiertes System    #"
    echo "# in der Standardkonfiguration handelt.                                                          #"
    echo "#                                                                                                #"
    echo "# !!! Ich bin in keiner Weise dafür verantwortlich, wenn an deinem System etwas kaputt geht,     #"
    echo "# auch wenn die wahrscheinlich dafür verschwindet gering ist !!!                                 #"
    echo "#                                                                                                #"
    echo "# Ich bin kein Programmierer oder Softwareentwickler. Ich versuche nur, einigen Anfängern das    #"
    echo "# Leben ein wenig zu erleichtern. ;-)                                                            #"
    echo "#                                                                                                #"
    echo "# Es wird Bugs oder Dinge geben, an die ich nicht gedacht habe - sorry - wenn das so ist,        #"
    echo "# versuchst Du am besten es selbst zu lösen oder lass es mich bitte wissen, eventuell kann ich   #"
    echo "# dir helfen das Problem zu lösen.                                                             #"
    echo "#                                                                                                #"
    echo -e "# \e[1;35mVERWENDUNG\e[0m                                                                                     #"
    echo "# Du kannst dieses Skript direkt ausführen, indem Du eine Konsole über deine Proxmox WebGUI      #"
    echo "# öffnest und folgendes eingibst:                                                                #"
    echo "# # bash <(wget -qO- https://install.shiot.de/pveConfig.sh)                                      #"
    echo "#                                                                                                #"
    echo "# Du kannst dieses Skript vor der Benutzung bearbeiten in dem Du es in der Shell herunterlädst   #"
    echo "# # wget https://install.shiot.de/pveConfig.sh                                                   #"
    echo "#                                                                                                #"
    echo "##################################################################################################"
    echo ""
    echo ""
    read -p "$(echo -e "$question") Ich habe den Text gelesen, zur Kenntnis genommen und bin damit einverstanden. $(echo -e "$yesno") " -rn1 && echo ""
    if [[ $REPLY =~ ^[JjYy]$ ]]; then
      startUserInput
    else
      echo -e "$error Unter diesen Umständen kann das Skript nicht ausgeführt werden, sorry."
      exit 1
    fi
  else
    echo -e "$error Unter diesen Umständen kann das Skript nicht ausgeführt werden, sorry."
    exit 1
  fi
}

function createPassword() {
  chars=({0..9} {a..z} {A..Z} "@" "%" "&" "+" "-")
  for i in $(eval echo "{1..$1}"); do
    echo -n "${chars[$(($RANDOM % ${#chars[@]}))]}"
  done 
}

function startUserInput() {
  networkrobotpw=$(createPassword 20)
  #wget -q $rawGitHubURL/lng.conf
  source $rawGitHubURL/lng.conf
  whiptail --backtitle "SmartHome-IoT.net" ${r} ${c} 10 --menu "choose" "${lng[@]}"
  wget -qO ./lng $rawGitHubURL/lng/$?
  source ./lng
  whiptail --msgbox --backtitle "SmartHome-IoT.net - $wlc" --title "$intr" "Bevor es los gehen kann werden noch einige angaben zu deinem Proxmoxsystem und deinem Netzwerk benötigt. Bitte stelle sicher, das alle angaben korrekt sind, da dieses Skript sonst nicht vollständig oder nur fehlerhaft ausgeführt werden kann, und die Konfiguration deines Proxmoxsystems, sowie die Erstellung und Konfiguration von Containern und virtuellen Maschinen nicht funktioniert.\n\nDie verwendung dieses Skripts setzt eine neue nicht konfigurierte Proxmox Installation vorraus." ${r} ${c}
  whiptail --msgbox --backtitle "SmartHome-IoT.net - Willkommen" --title "Netzwerkroboter" "Es macht in einem Netzwerk Sinn, einen so genannten Netzwerkroboter zu erstellen.\n\nEin Netzwerkroboter hat auf allen Geräten im Netzwerk Administratorrechte. So könnnen mit einem Benutzer sämtliche automatisierten Aufgaben erledigt werden.\n\nNatürlich muss einem solchen Benutzer ein extrem sicheres Passwort zugewiesen werden. Wenn Du einen solchen Benutzer erstellst, gib diesem einen eindeutigen Namen wie z.B. netrobot." ${r} ${c}
  whiptail --msgbox --backtitle "SmartHome-IoT.net - Willkommen" --title "Sicheres Passwort" "Dieses Passwort wird zufällig von diesem Skript erstellt, nach beenden des Skript gelöscht und kann nicht wiederhergestellt werden. Aus diesem Grund solltest du es notieren. Für diesen Zweck nutzt man am besten einen Passwortmanager wie z.B. safeincloud.\n\nAutomatisch generiertes Passwort: $networkrobotpw \n\nDie sicherheit deines Passworts kannst du z.B. auf der Internetseite https://password.kaspersky.com/de/ leicht überprüfen." ${r} ${c}
  varpverootpw=$(whiptail --inputbox --nocancel --backtitle "SmartHome-IoT.net - Netzwerkinfrastruktur" --title "Proxmox Root-Passwort" "Wie lautet das Root-Passwort von deinem Proxmox Server?" ${r} ${c} 3>&1 1>&2 2>&3)
  varrobotname=$(whiptail --inputbox --nocancel --backtitle "SmartHome-IoT.net - Netzwerkinfrastruktur" --title "Netzwerkrobotername" "Welchen Benutzernamen hast du für deinen Networkrobot gewählt?" ${r} ${c} netrobot 3>&1 1>&2 2>&3)
  varrobotpw=$(whiptail --passwordbox --nocancel --backtitle "SmartHome-IoT.net - Netzwerkinfrastruktur" --title "Netzwerkroboterpasswort" "Welches Passwort hast du für deinen Networkrobot gewählt?\n\nVorausgefüllt mit dem automatisch generierten Passwort." ${r} ${c} $networkrobotpw 3>&1 1>&2 2>&3)
  whiptail --radiolist --backtitle "SmartHome-IoT.net - Netzwerkinfrastruktur" --title "Gateway/Router" "Was für ein Gateway/Router verwendest du?" ${r} ${c} 3 \
    "UniFi/Ubiquiti" "DreamMachine Pro oder CloudKey" on \
    "AVM" "FRITZ!Box" off \
    "Andere" "Ein nicht aufgührter Hersteller" off 2>gwchoice
  gwchoice=`cat gwchoice`
  if [[ $gwchoice == "UniFi/Ubiquiti" ]]; then
    vargwmanufacturer="unifi"
  elif [[ $gwchoice == "AVM" ]]; then
    vargwmanufacturer="avm"
  else
    whiptail --msgbox --backtitle "SmartHome-IoT.net - Netzwerkinfrastruktur" --title "Gateway/Router" "Momentan kann dieses Script nur Geräte von Ubiquiti/Unifi und AVM (FRITZ!Box) automatisch bearbeiten." ${r} ${c}
  fi
  if [[ $vargwmanufacturer == "unifi" ]]; then
    whiptail --yesno --backtitle "SmartHome-IoT.net - Netzwerkinfrastruktur" --title "VLAN" "Nutzt Du VLANs in deinem Netzwerk?" ${r} ${c}
    yesno=$?
    if [[ $yesno == 0 ]]; then
      vlanexists=y
      varservervlan=$(whiptail --inputbox --nocancel --backtitle "SmartHome-IoT.net - Netzwerkinfrastruktur" --title "Server VLAN" "Wie lautet die VLAN-ID die für dein Servernetzwerk genutzt werden soll?\nDefault = 1" ${r} ${c} 1 3>&1 1>&2 2>&3)
      varsmarthomevlan=$(whiptail --inputbox --nocancel --backtitle "SmartHome-IoT.net - Netzwerkinfrastruktur" --title "SmartHome VLAN" "Wie lautet die VLAN-ID die für dein Smarthomenetzwerk genutzt werden soll?" ${r} ${c} 10 3>&1 1>&2 2>&3)
      varguestvlan=$(whiptail --inputbox --nocancel --backtitle "SmartHome-IoT.net - Netzwerkinfrastruktur" --title "Gast VLAN" "Wie lautet die VLAN-ID die für dein Gästenetzwerk genutzt werden soll?" ${r} ${c} 100 3>&1 1>&2 2>&3)
    else
      vlanexists=n
    fi
  else
    whiptail --msgbox --backtitle "SmartHome-IoT.net - Netzwerkinfrastruktur" --title "VLAN" "Ein Virtual Local Area Network (VLAN) ist ein logisches Netz, das auf einem physischen LAN aufsetzt und ein Mehr an Flexibilität, Performance und Sicherheit bieten kann. Mit VLANs lassen sich physische LANs in voneinander isolierte, logische Teilnetze aufteilen. Die Unterteilung von LANs ist dabei kein Selbstzweck, sondern soll auch Performance und Sicherheit optimieren.\n\nAus diesem Grund solltest Du über die Verwendung von VLANs nachdenken." ${r} ${c}
  fi
  varrootmail=$(whiptail --inputbox --nocancel --backtitle "SmartHome-IoT.net - E-Mailkonfiguration" --title "Empfängeradresse" "An welche E-Mail-Adresse sollen Benachrichtigungen und Systemreports gesendet werden?" ${r} ${c} 3>&1 1>&2 2>&3)
  varmailserver=$(whiptail --inputbox --nocancel --backtitle "SmartHome-IoT.net - E-Mailkonfiguration" --title "Mailserver" "Wie lautet der Hostname des Mailserver (Ein-/Ausgangsserver)?" ${r} ${c} 3>&1 1>&2 2>&3)
  varmailport=$(whiptail --inputbox --nocancel --backtitle "SmartHome-IoT.net - E-Mailkonfiguration" --title "Mailserver" "Wie lautet der SMTP-Port des Mailservers (in den meisten Fällen 587)?" ${r} ${c} 587 3>&1 1>&2 2>&3)
  varmailusername=$(whiptail --inputbox --nocancel --backtitle "SmartHome-IoT.net - E-Mailkonfiguration" --title "Mailserver - Benutzername" "Wie lautet der Benutzername der für den Login am Mailserver benötigt wird?" ${r} ${c} 3>&1 1>&2 2>&3)
  varmailpassword=$(whiptail --passwordbox --nocancel --backtitle "SmartHome-IoT.net - E-Mailkonfiguration" --title "Mailserver - Passwort" "Wie lautet das Passwort von $varmailusername, welches für den Login benötigt wird?" ${r} ${c} 3>&1 1>&2 2>&3)
  varsenderaddress=$(whiptail --inputbox --nocancel --backtitle "SmartHome-IoT.net - E-Mailkonfiguration" --title "Mailserver - Absender" "Wie lautet die Absendeadresse?" ${r} ${c} "notify@$(echo "$varrootmail" | cut -d\@ -f2)" 3>&1 1>&2 2>&3)
  whiptail --yesno --backtitle "SmartHome-IoT.net - E-Mailkonfiguration" --title "Mailserver - Sicherheit" "Wird für die Verbindung TLS/SSL benutzt?" ${r} ${c}
  yesno=$?
  if [[ $yesno == 0 ]]; then
    vartls=yes
  else
    vartls=no
  fi
  whiptail --yesno --backtitle "SmartHome-IoT.net - Speicher- und NAS-Konfiguration" --title "NAS-Konfiguration" "Befindet sich eine NAS (Qnap, Synology, usw.) in deinem Netzwerk?" ${r} ${c}
  yesno=$?
  if [[ $yesno == 0 ]]; then
    function pingNAS() {
      varnasip=$(whiptail --inputbox --nocancel --backtitle "SmartHome-IoT.net - Speicher- und NAS-Konfiguration" --title "NAS-Konfiguration" "Wie lautet die IP-Adresse deiner NAS?" ${r} ${c} 3>&1 1>&2 2>&3)
      if ping -c 1 "$varnasip" > /dev/null 2>&1; then
        varnasexists=y
        {
          for ((i = 98 ; i <= 100 ; i+=1)); do
            sleep 0.5
            echo $i
          done
        } | whiptail --gauge "Deine NAS wird im Netzwerk gesucht ..." ${r} ${c} 50
      else
        {
          for ((i = 98 ; i <= 100 ; i+=1)); do
            sleep 0.5
            echo $i
          done
        } | whiptail --gauge "Deine NAS wird im Netzwerk gesucht ..." ${r} ${c} 22
        whiptail --msgbox --backtitle "SmartHome-IoT.net - Speicher- und NAS-Konfiguration" --title "NAS-Konfiguration" "Die angegene IP-Adresse ist nicht erreichbar. Bitte prüfe ob die NAS angeschaltet und mit dem Netzwerk verbunden ist." ${r} ${c}
        pingNAS
      fi
    }
    pingNAS
    whiptail --yesno --backtitle "SmartHome-IoT.net - Speicher- und NAS-Konfiguration" --title "NAS-Konfiguration" "Handelt es sich bei dieser NAS um eine Synology DiskStation?" ${r} ${c}
    yesno=$?
    if [[ $yesno == 1 ]]; then
      varsynologynas=y
    else
      varsynologynas=n
    fi
    whiptail --yesno --backtitle "SmartHome-IoT.net - Speicher- und NAS-Konfiguration" --title "NAS-Konfiguration" "In diesem Skript werden auf der NAS zwei freigegebene Ordner benötigt. Erstelle die folgenden Ordner und weise dem Benutzer $varrobotname Lese/Schreibrechte zu.\n\nbackups\nmedia\n\nHast Du diese Ordner erstellt und deinem Netzwerkroboter $varrobotname Lese/Schreibrechte zugewiesen?" ${r} ${c}
    yesno=$?
    if [[ $yesno == 1 ]]; then
      whiptail --msgbox --backtitle "SmartHome-IoT.net - Speicher- und NAS-Konfiguration" --title "NAS-Konfiguration" "Wenn der Netzwerkroboter keine Lese-/Schreibrechte auf die Ordner besitzt, kann dieses Konfigurationsscript nicht ordnungsgemäß arbeiten, sorry.\n\nDas Skript wird beendet" ${r} ${c}
      exit 1
    fi
  else
    varnasexists=n
    whiptail --msgbox --backtitle "SmartHome-IoT.net - Speicher- und NAS-Konfiguration" --title "NAS-Konfiguration" "Es wird empfohlen eine NAS in einem privaten Netzwerk zu verbauen. Da du keine NAS besitzt oder angeben willst ist die Installation einiger Server nicht verfügbar." ${r} ${c}
  fi
  wget -q $rawGitHubURL/lxc.conf
  source ./lxc.conf
  whiptail --checklist --nocancel --backtitle "SmartHome-IoT.net - Containerkonfiguration" --title "Container - Installation" "Wähle aus der Liste die zu installierenden Server." ${r} ${c} 10\
          ReverseProxy "NGINX Proxy Manager" on \
          AdBlockerVPN "piHole mit piVPN"   on  \
          iDBGrafana "influxDB mit Grafana"   on \
          "${lxc[@]}" 2>lxcchoice
  whiptail --yesno --backtitle "SmartHome-IoT.net - Konfigurationsabschluss" --title "Benutzereingaben beendet" "Die Konfiguration ist beendet, das Skript wird nun mit deinen Vorgaben ausgeführt. Je nachdem welche Container du für die Installation gewählt hast, werden weiter Benutzereingaben benötigt.\n\nSoll Proxmox nach deinen Vorgaben konfiguriert werden?" ${r} ${c}
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    startConfig
  else
    whiptail --msgbox --backtitle "SmartHome-IoT.net" --title "Abbruch" "Es werden keine änderungen an deinem Proxmoxserver vorgenommen. Wenn du die konfiguration durch dieses Skript vornehmen möchtest, musst du es erneut ausführen." ${r} ${c}
    exit 1
  fi
}

# Grundeinstellungen für Proxmox
function startConfig() {
  # Richtet Proxmox richtig für E-Mailbenachrichtigungen ein
  function configEmail() {
    if [ $(grep -crnwi '/etc/default/smartmontools' -e '43200') -eq 0 ]; then
      echo -e "$info Beginne bearbeitung!"
      echo -e "$info Aliase setzen"
      if grep "root:" /etc/aliases; then
        echo -e "$info Aliases-Eintrag wurde gefunden: Bearbeitung für $varrootmail"
        sed -i "s/^root:.*$/root: $varrootmail/" /etc/aliases
      else
        echo -e "$error Kein Root-Alias gefunden"
        echo -e "$info Root-Alias wird hinzugefügt"
        echo "root: $varrootmail" >> /etc/aliases
      fi
      echo "root $varsenderaddress" >> /etc/postfix/canonical
      chmod 600 /etc/postfix/canonical

      # Vorbereitung für Passworthash
      echo [$varmailserver]:"$varmailport" "$varmailusername":"$varmailpassword" >> /etc/postfix/sasl_passwd
      chmod 600 /etc/postfix/sasl_passwd 

      # Mailserver in main.cf hinzufügen
      sed -i "/#/!s/\(relayhost[[:space:]]*=[[:space:]]*\)\(.*\)/\1"[$varmailserver]:"$varmailport""/"  /etc/postfix/main.cf

      # TLS-Einstellungen prüfen
      echo -e "$info Es werden die richtigen TLS-/SSL-Einstellungen vorgenommen"
      if [ $vartls -eq 0 ]; then
        postconf smtp_use_tls=yes
      else
        postconf smtp_use_tls=yes
      fi

      # Prüfen auf Passwort-Hash-Eingabe
      if grep "smtp_sasl_password_maps" /etc/postfix/main.cf; then
        echo -e "$info Passwort-Hash wurde gefunden"
      else
        echo -e "$error Kein Passwort-Hash gefunden: wird hinzugefügt"
        postconf smtp_sasl_password_maps=hash:/etc/postfix/sasl_passwd
      fi

      #Überprüfung auf Zertifikat
      if grep "smtp_tls_CAfile" /etc/postfix/main.cf; then
        echo -e "$info TLS/SSL CA Zertifikat gefunden"
      else
        postconf smtp_tls_CAfile=/etc/ssl/certs/ca-certificates.crt
      fi

      # Hinzufügen von sasl-Sicherheitsoptionen und beseitigt standardmäßige Sicherheitsoptionen, die nicht mit Google Mail kompatibel sind
      if grep "smtp_sasl_security_options" /etc/postfix/main.cf; then
        echo -e "$info Google smtp_sasl_security_options gefunden"
      else
        postconf smtp_sasl_security_options=noanonymous
      fi
      if grep "smtp_sasl_auth_enable" /etc/postfix/main.cf; then
        echo -e "$info Authentifizierung aktiviert"
      else
        postconf smtp_sasl_auth_enable=yes
      fi 
      if grep "sender_canonical_maps" /etc/postfix/main.cf; then
        echo -e "$info Canonical Eintrag gefunden"
      else
        postconf sender_canonical_maps=hash:/etc/postfix/canonical
      fi 

      echo -e "$info Passwort und Canonical Eintrag verschlüsseln"
      postmap /etc/postfix/sasl_passwd
      postmap /etc/postfix/canonical
      echo -e "$info Neustart von postfix und Aktivierung des autostarts"
      systemctl restart postfix  &> /dev/null && systemctl enable postfix  &> /dev/null
      echo -e "$info Bereinigung der Datei die zum Erzeugen des Passwort-Hashes verwendet wird"
      rm -rf "/etc/postfix/sasl_passwd"
      echo -e "$info Dateien bereinigt"

      # Testen der E-Mail Einstellungen
      emailSTATUS="$ok E-Mail erfolgreich zugestellt"
      echo -e "$ok Konfiguration abgeschlossen, testen wir das ganze..."
      echo -e "$info Es wird eine E-Mail an folgende Adresse versendet: $varrootmail"
      echo -e "Wenn diese E-Mail empfangen wurde, kann in dem Skript weiter gemacht werden.\n\nBitte bestätigen Sie den Empfang der E-Mail mit ""Ja"" im Skript." | mail -s "[pve] Testnachricht Installationsskript" "$varrootmail"
      read -p "$(echo -e "$question") Wurde die E-Mail erfolgreich zugestellt (Es kann je nach Anbieter bis zu 15 Minuten dauern)? $(echo -e "$yesno") " -rn1 && echo ""
      if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo -e "$error Prüfe auf bekannte Fehler, die in Protokollen gefunden werden können"
        if grep "SMTPUTF8 is required" "/var/log/mail.log"; then
          echo -e "$ok Es könnten Fehler gefunden worden sein"
          read -p "$(echo -e "$question") Sieht aus, als gäbe es einen Fehler mit der SMTPUTF8 konfiguration. Soll versucht werden diese zu beheben? $(echo -e "$yesno") " -rn1 && echo ""
          if [[ $REPLY =~ ^[Jj]$ ]]; then
            if grep "smtputf8_enable = no" /etc/postfix/main.cf; then
              echo -e "$info Korrektur bereits angewendet!"
            else
              echo -e "$info Setzen von ""smtputf8_enable=no"" zur Korrektur von ""SMTPUTF8 was required but not supported"""
              postconf smtputf8_enable=no
              postfix reload
            fi
          fi
        else
          echo -e "$info Keine konfigurationsfehler gefunden"
        fi
        echo -e "Wenn diese E-Mail empfangen wurde, kann in dem Skript weiter gemacht werden.\n\nBitte bestätigen Sie den Empfang der E-Mail mit ""Ja"" im Skript." | mail -s "[pve] Testnachricht Installationsskript" "$varrootmail"
        read -p "$(echo -e "$question") Wurde die E-Mail jetzt erfolgreich zugestellt? $(echo -e "$yesno") " -rn1 && echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
          emailSTATUS="$error E-Mail konnte nicht erfolgreich zugestellt werden."
          echo -e "$info Das Fehlerprotokol ist in der Datei ""/var/log/mail.log"" zu finden. Dieses Skript kann hier nichts mehr tun. - Sorry"
          exit 1
        fi
      fi
      echo -e "$emailSTATUS"

      # E-Mailbenachrichtigung über Festplattenfehler, prüfung alle 12 Stunden
      sed -i 's+#enable_smart="/dev/hda /dev/hdb"+enable_smart="/dev/'"$rootDisk"'"+' /etc/default/smartmontools
      sed -i 's+#smartd_opts="--interval=1800"+smartd_opts="--interval=43200"+' /etc/default/smartmontools
      echo "start_smartd=yes" > /etc/default/smartmontools
      sed -i 's+DEVICESCAN -d removable -n standby -m root -M exec /usr/share/smartmontools/smartd-runner+#DEVICESCAN -d removable -n standby -m root -M exec /usr/share/smartmontools/smartd-runner+' /etc/smartd.conf
      sed -i 's+# /dev/sda -a -d sat+/dev/'"$rootDisk"' -a -d sat+' /etc/smartd.conf
      sed -i 's+#/dev/sda -d scsi -s L/../../3/18+/dev/'"$rootDisk"' -d sat -s L/../../1/02 -m root+' /etc/smartd.conf
      systemctl start smartmontools
    fi
    return 0
  }

  # Prüft ob im System eine weitere SSD verbaut ist, und richtet diese als Datenfestplatte ein
  function configHDD() {
    countDisks=$(echo "$otherDisks" | wc -l)
    if [ "$countDisks" -eq 0 ]; then
      echo -e "$info In diesem System wurden keine weiteren Festplatten gefunden."
    elif [ "$countDisks" -eq 1 ]; then
      if [ $(pvesm status | grep -c data) -eq 0 ]; then
        if [ $(cat /sys/block/"$otherDisks"/queue/rotational) -eq 0 ]; then
            if [ $(pvesm status | grep 'data' | grep -c 'active') -eq 0 ]; then
              echo -e "$info Es wurde eine weitere Festplatte SSD im System gefunden. Diese wird als Datenfestplatte eingebunden."
              parted -s /dev/"$otherDisks" "mklabel gpt" > /dev/null 2>&1
              parted -s -a opt /dev/"$otherDisks" mkpart primary ext4 0% 100% > /dev/null 2>&1
              mkfs.ext4 -Fq -L data /dev/"$otherDisks"1 > /dev/null 2>&1
              mkdir -p /mnt/data > /dev/null 2>&1
              mount -o defaults /dev/"$otherDisks"1 /mnt/data > /dev/null 2>&1
              UUID=$(lsblk -o LABEL,UUID | grep 'data' | awk '{print $2}')
              echo "UUID=$UUID /mnt/data ext4 defaults 0 2" > /etc/fstab
              pvesm add dir data --path /mnt/data
              pvesm set data --content iso,vztmpl,rootdir,images
              pvesm set local --content snippets,backup
              pvesm set local-lvm --content images
              downloadPath="data"
              echo -e "$ok Die Festplatte wurde mit dem Namen $(echo -e '\e[1;36m')data$(echo -e '\e[0m') in Proxmox eingebunden."

              # E-Mailbenachrichtigung über Festplattenfehler, prüfung alle 12 Stunden
              sed -i 's+enable_smart="/dev/'"$rootDisk"'"+enable_smart="/dev/'"$rootDisk"' /dev/'"$otherDisks"'"+' /etc/default/smartmontools
              sed -i 's+/dev/'"$rootDisk"' -a -d sat+/dev/'"$rootDisk"' -a -d sat\n/dev/'"$otherDisks"' -a -d sat+' /etc/smartd.conf
              sed -i 's+#/dev/sdb -d scsi -s L/../../7/01+/dev/'"$otherDisks"' -d sat -s L/../../1/03 -m root+' /etc/smartd.conf
              systemctl restart smartmontools
              confignotemailcontent="${confignotemailcontent}Eingebundene Festplatten\nFestplatten Typ: SSD\nFestplatte: /dev/$otherDisks\nMountpfad: /mnt/data\nProxmox Name: data\n\n\n"
            fi
        else
          echo -e "$error Die im System gefundene Festplatte ist keine SSD!"
        fi
      else
        downloadPath="data"
      fi
    else
      echo -e "$info Es wurden mehrere zusätzliche Festplatten im System gefunden."
      return 1
    fi
    return 0
  }

  # Erzeugt einen Adminbenutzer für Proxmox, um sich nicht als Root einloggen zu müssen
  function configUser() {
    if [ $(pveum user list | grep -c 'Proxmox WebGUI-Administrator') -eq 0 ]; then
      echo -e "$info Um sich nicht als ROOT an der WebGUI anmelden zu müssen, wird ein Adminbenutzer für die WebGUI erstellt"
      adminpw=$(createPassword 8)
      pveum groupadd admin -comment "WebGUI Administrator"
      sleep 5
      pveum aclmod / -group admin -role Administrator
      sleep 5
      pveum useradd "admin@pve" -comment "Proxmox WebGUI-Administrator" -groups admin -password "$adminpw"
    fi
    return 0
  }

  # Entfernt das Enterprise Repository und ersetzt es durch das Community Repository
  if [ -f "/etc/apt/sources.list.d/pve-enterprise.list" ]; then
    echo -e "$info Entferne Enterprise Repository"
    rm /etc/apt/sources.list.d/pve-enterprise.list
  fi
  if [ ! -f "/etc/apt/sources.list.d/pve-community.list" ]; then
    echo -e "$info Erstelle Community Repository"
    echo "deb http://download.proxmox.com/debian/pve $osname pve-no-subscription" > /etc/apt/sources.list.d/pve-community.list
  fi
  if [ ! -f "/etc/apt/sources.list.d/ceph.list" ]; then
    echo -e "$info Erstelle Ceph Repository"
    echo "deb http://download.proxmox.com/debian/ceph-octopus $osname main" > /etc/apt/sources.list.d/ceph.list
  fi

  # Führt ein Systenupdate aus und installiert für dieses Script benötigte Software
  softwaretoinstall="curl parted smartmontools libsasl2-modules"
  echo -e "$info Benötigte Updates werden geladen und installiert, je nach Internetverbindung kann dies einige Zeit in Anspruch nehmen."
  apt-get update > /dev/null 2>&1 && apt-get upgrade -y 2>&1 >/dev/null && pveam update 2>&1 >/dev/null
  echo -e "$ok Alle Systemupdates und benötigte Software wurde installiert"
  for package in $softwaretoinstall; do
    if [ $(dpkg-query -W -f='${Status}' "$package" | grep -c "ok installed") -eq 0 ]; then
      apt-get install -y "$package" > /dev/null 2>&1
      echo -e "$ok $package wurde installiert"
    fi
  done

  configEmail

  # Aktiviere S.M.A.R.T. support auf Systemfestplatte
  if [ $(smartctl -a /dev/"$rootDisk" | grep -c "SMART support is: Enabled") -eq 0 ]; then
    echo -e "$info Aktiviere S.M.A.R.T. Support auf der Systemfestplatte"
    smartctl -s on -a /dev/"$rootDisk"
  fi

  configHDD

  return 0
}

function containerSetup() {
  # Generates an ID and an IP address for the container to be created
  function createIDIP() {
    if [ $(pct list | grep -c 100) -eq 0 ]; then
      nextCTID=100
      lastCTIP=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | cut -d/ -f1 | cut -d. -f4)
      nextCTIP=$networkIP.$(( "$lastCTIP" + 5 ))
    else
      lastCTID=$(pct list | tail -n1 | awk '{print $1}')
      nextCTID=$(( "$lastCTID" + 1 ))
      lastCTIP=$(lxc-info "$lastCTID" -iH | grep "$networkIP" | cut -d. -f4)
      nextCTIP=$networkIP.$(( "$lastCTIP" + 1 ))
    fi
  }

  # Loads the container template from the Internet if not available and saves it for further use
  function downloadTemplate() {
    pveam update > /dev/null 2>&1
    echo -e "$info Prüfe ob das benötigte Template für $1 vorhanden ist"
    if [[ $1 == "ubuntu" ]]; then
      ctTemplate=$(pveam available | grep $osUbuntu | awk '{print $2}')
      if [ $(pveam list "$downloadPath" | grep -c "$ctTemplate") -eq 0 ]; then
        echo -e "$error Template nicht vorhanden, beginne download..."
        pveam download "$downloadPath" "$ctTemplate" > /dev/null 2>&1
        echo -e "$ok Templatedownload erfolgreich abgeschlossen"
      else
        echo -e "$ok Template vorhanden, kein download notwendig"
      fi
      ctOstype="ubuntu"
    elif [[ $1 == "ubuntu18" ]]; then
      ctTemplate=$(pveam available | grep $osUbuntu18 | awk '{print $2}')
      if [ $(pveam list "$downloadPath" | grep -c "$ctTemplate") -eq 0 ]; then
        echo -e "$error Template nicht vorhanden, beginne download..."
        pveam download $downloadPath "$ctTemplate" > /dev/null 2>&1
        echo -e "$ok Templatedownload erfolgreich abgeschlossen"
      else
        echo -e "$ok Template vorhanden, kein download notwendig"
      fi
      ctOstype="ubuntu"
    elif [[ $1 == "debian" ]]; then
      ctTemplate=$(pveam available | grep $osDebian | awk '{print $2}')
      if [ $(pveam list "$downloadPath" | grep -c "$ctTemplate") -eq 0 ]; then
        echo -e "$error Template nicht vorhanden, beginne download..."
        pveam download "$downloadPath" "$ctTemplate" > /dev/null 2>&1
        echo -e "$ok Templatedownload erfolgreich abgeschlossen"
      else
        echo -e "$ok Template vorhanden, kein download notwendig"
      fi
      ctOstype="debian"
    else
      echo -e "$error Kein Template für den Container gefunden, ein download ist nicht möglich."
    fi
  }
# $1=ctTemplate (ubuntu/debian/turnkey-openvpn) - $2=hostname - $3=ContainerRootPasswort - $4=hdd size - $5=cpu cores - $6=RAM Swap/2 - $7=features (keyctl=1,nesting=1,mount=cifs)
  createIDIP
  echo -e "\e[1;35mErstelle Container $nextCTID - $2\e[0m"
  downloadTemplate "$1"
  ctRootpw "$3"
  features="$7"
  pct create "$nextCTID" \
    data:vztmpl/"$ctTemplate" \
    --ostype "$ctOstype" \
    --hostname "$2" \
    --password "$3" \
    --rootfs "$downloadPath":"$4" \
    --cores "$5" \
    --memory "$6" \
    --swap $(( $6 / 2 )) \
    --net0 bridge=vmbr0,name=eth0,ip="$nextCTIP"/$cidr,gw="$gatewayIP",ip6=dhcp,firewall=1 \
    --onboot 1 \
    --force 1 \
    --unprivileged 1 \
    --start 1 \
    --features "$features" > /dev/null 2>&1
  echo -e "$info Der Container $nextCTID - $2 wird aktualisiert"
  pct exec $nextCTID -- bash -c "locale-gen en_US.UTF-8 > /dev/null 2>&1" # get en_US Language Support for the shell
  pct exec $nextCTID -- bash -c "export LANGUAGE=en_US.UTF-8"
  pct exec $nextCTID -- bash -c "export LANG=en_US.UTF-8"
  pct exec $nextCTID -- bash -c "export LC_ALL=en_US.UTF-8"
  pct exec $nextCTID -- bash -c "locale-gen en_US.UTF-8 > /dev/null 2>&1" # must do it for 2nd Time to set it right
  pct exec $nextCTID -- bash -c "apt-get update > /dev/null 2>&1 && apt-get upgrade -y > /dev/null 2>&1"
  for package in $ctStandardsoftware; do
    echo -e "$info $package wird auf dem Container $nextCTID - $2 installiert"
    pct exec $nextCTID -- bash -c "apt-get install -y $package > /dev/null 2>&1"
  done
  pct exec $nextCTID -- bash -c "apt-get dist-upgrade -y > /dev/null 2>&1"
  echo -e "$ok Der Container $nextCTID - $2 wurde erstellt und der die Grundkonfiguration wurde abgeschlossen"
  pct shutdown $nextCTIP --timeout 5
  sleep 10
  return $nextCTID
}

#shellStart
startUserInput

if ! [ -w ./lxcchoice ]; then echo -e "$error Die Konfigurationsdatei für die gewählten Container ist nicht lesbar." && exit 1; fi

lxcchoice="$(cat ./lxcchoice)"

for lxc in $lxcchoice; do
  echo -e "$info Es wird versucht $lxc auf Proxmox zu installieren"
  ctName="$lxc"
  ctRootpw=$(createPassword 12)
  if [ $(pct list | grep -c "$lxc") -eq 0 ]; then
    echo "Installation von $lxc beginnt!"
    #curl -sSL $rawGitHubURL/$lxc/install.sh
  else
    echo -e "$error Es existiert bereits ein Container mit dem Namen $lxc"
  fi
done
