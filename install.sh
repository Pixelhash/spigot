#!/bin/bash
DEBIAN_FRONTEND="noninteractive"
TERM=xterm-256color
export TERM
export DEBIAN_FRONTEND

source functions.sh

version=0.1
banner="###############################\n $(yellowb Spigot) Setup Script by CodeHat\n###############################"

if [ "$EUID" -ne 0 ]
	then echo $(redb "Please run as root")
	exit
fi

set_config () {
  sudo sed -i "s/^\($1\s*=\s*\).*\$/\1$2/" $CONFIG
}

show_help () {
  echo $(redb "Unknown command '$1'.")
	echo "Use -h for all commands."
}

show_cmds () {
	echo -e $banner
	echo
	echo "Command reference:"
  echo
  echo "  $(textb -i)    Installs Spigot and MariaDB (optional)"
  echo "  $(textb -u)    Uninstalls Spigot"
  echo "  $(textb -h)    Shows this help page"
  echo "  $(textb -v)    Shows the script's version"
}

case $1 in
  "-i")
    echo "$(greenb [?]) Are you sure you want to install Spigot?"
    read -p '(y/n): ' choice
    if [[ $choice == "y" ]]
    then
        MARIADB=false
        echo "$(greenb [?]) Do you want to install MariaDB?"
        read -p '(y/n): ' choice
        if [[ $choice == "y" ]]
        then
          MARIADB=true
        fi
      echo "$(greenb [START]) Installing Spigot"
      echo
      install_spigot $MARIADB
    else
      echo "Aborted."
      exit 0
    fi
    ;;
  "-u")
    echo "Uninstalling..."
    ;;
  "-h")
    show_cmds
    ;;
  "-v")
    echo "$(yellowb Spigot) Script v$version"
    ;;
  *)
    show_help $1
    ;;
esac
