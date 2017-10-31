textb () {
	echo $(tput bold)${1}$(tput sgr0);
}

greenb () {
	echo $(tput bold)$(tput setaf 2)${1}$(tput sgr0);
}

redb () {
	echo $(tput bold)$(tput setaf 1)${1}$(tput sgr0);
}

yellowb () {
	echo $(tput bold)$(tput setaf 3)${1}$(tput sgr0);
}

pinkb () {
	echo $(tput bold)$(tput setaf 5)${1}$(tput sgr0);
}

_game="spigot"
_user="spigot"
_server_root="/srv/spigot"
_mc_version=1.12.2

genpasswd () {
  count=0
  while [ ${count} -lt 3 ]; do
    pw_valid=$(tr -cd A-Za-z0-9 < /dev/urandom | fold -w24 | head -n1)
    count=$(grep -o "[0-9]" <<< ${pw_valid} | wc -l)
  done
  echo ${pw_valid}
}

update () {
  echo "Adding Java 8 repository..."
  add-apt-repository ppa:webupd8team/java -y >> spigot.log 2>&1

  if [[ $1 == true ]]
  then
    echo "Adding MariaDB repository..."
    apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8 >> spigot.log 2>&1
    add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mirror.23media.de/mariadb/repo/10.2/ubuntu xenial main' >> spigot.log 2>&1
  fi

  echo "Updating package list..."
  apt-get update -y >> spigot.log 2>&1
}

setup () {
  # 0 if "_user" exists, or 1 if not
  user_exists=$(id -u $_user > /dev/null 2>&1; echo $?)

  if [ ! -d "${_server_root}" ]; then
    echo "Creating ${_server_root} folder..."
    mkdir "${_server_root}"
  fi

  if [[ $user_exists == 1 ]]; then
    getent group "${_user}" &>/dev/null
    if [ $? -ne 0 ]; then
      echo "Adding ${_user} system group..."
      groupadd -r ${_user} 1>/dev/null
    fi

    getent passwd "${_user}" &>/dev/null
    if [ $? -ne 0 ]; then
      echo "Adding ${_user} system user..."
      useradd -r -g ${_user} -d "${_server_root}" ${_user} 1>/dev/null
    fi
  else
    echo "User ${_user} already exists. Skipping user creation..."
  fi

  echo "Installing prerequisites for Java 8, (MariaDB), Spigot..."
  apt-get install software-properties-common tar netcat screen git -y >> spigot.log 2>&1
}

oracle-java () {
  # Set debconf selection to handle input via installer.
  debconf-set-selections <<< "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" >> spigot.log 2>&1

  # Install Java 8.
  apt-get install oracle-java8-installer -y >> spigot.log 2>&1
}

mariadb () {
  # Generate pasword for MariaDB root user.
  _mdb_pw=$(genpasswd)
  echo "$(yellowb [PASSWORD]) root ${_mdb_pw}"

  # Set debconf selection to handle input via installer.
  debconf-set-selections <<< "maria-db-10.2 mysql-server/root_password password $_mdb_pw" >> spigot.log 2>&1
  debconf-set-selections <<< "maria-db-10.2 mysql-server/root_password_again password $_mdb_pw" >> spigot.log 2>&1

  apt-get install mariadb-server -y >> spigot.log 2>&1
}

spigot () {
  echo "$(greenb [?]) Do you want to build Spigot now?"
  read -p '(y/n): ' choice
  if [[ $choice == "y" ]]
  then
    build_spigot $_mc_version
  else
    echo "$(greenb [SUCCESS]) "Skipping" Building Spigot"
  fi

  echo "Moving required files..."
  install -Dm644 scripts/${_game}.conf              "/etc/default/${_game}" >> spigot.log 2>&1
  install -Dm755 scripts/${_game}.sh                "/usr/local/bin/${_game}" >> spigot.log 2>&1
  install -Dm644 scripts/${_game}.service           "/etc/systemd/system/${_game}.service" >> spigot.log 2>&1
  install -Dm644 scripts/${_game}-backup.service    "/etc/systemd/system/${_game}-backup.service" >> spigot.log 2>&1
  install -Dm644 scripts/${_game}-backup.timer      "/etc/systemd/system/${_game}-backup.timer" >> spigot.log 2>&1

  echo "Creating logs folder..."
  install -dm775 "${_server_root}/logs" >> spigot.log 2>&1

  echo "Linking logs folder to /var/log/${_game} ..."
  ln -s "${_server_root}/logs" "/var/log/${_game}" >> spigot.log 2>&1

  echo "Creating plugins folder ..."
  install -dm775 "${_server_root}/plugins" >> spigot.log 2>&1

  echo "Setting permissions ..."
  chown -R ${_user}:${_user} "${_server_root}" >> spigot.log 2>&1
  chmod g+ws "${_server_root}" >> spigot.log 2>&1
}

build_spigot () {
  echo "$(pinkb [TASK]) Building Spigot"
  echo

  version=$1

  if [ ! -d "${_server_root}/build" ]; then
    echo "Creating ${_server_root}/build folder..."
    mkdir "${_server_root}/build" >> spigot.log 2>&1
  fi

  echo "Downloading latest BuildTools..."
  wget -O "${_server_root}/build/BuildTools.jar" "https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar" >> spigot.log 2>&1

  echo "Building Spigot for Minecraft ${version}... (This may take a while)"
  _current_dir=$(pwd)
  cd "${_server_root}/build"
  java -jar "${_server_root}/build/BuildTools.jar" --rev ${version} >> $_current_dir/spigot.log 2>&1
  cd $_current_dir

  echo "Creating symbolic link of spigot jar file..."
  ln -s "${_server_root}/build/spigot-${version}.jar" "${_server_root}/spigot-${version}.jar" >> spigot.log 2>&1

  echo "$(greenb [SUCCESS]) "Building Spigot" finished"
  echo
}

restart_all () {
  systemctl restart mysql >> spigot.log 2>&1
}

installtask () {
  case $1 in
    "update")
      update $2
      ;;
    "setup")
      setup
      ;;
    "oracle-java")
      oracle-java
      ;;
    "mariadb")
      mariadb
      ;;
    "spigot")
      spigot
      ;;
    "restart")
      restart_all
      ;;
    *)
      echo "$(redb "Task '$1' not found! Aborting...")"
      ;;
    esac
}

install_spigot () {
  > spigot.log

  echo "$(pinkb [TASK]) Setup"
  installtask setup
  echo "$(greenb [SUCCES]) "Setup" finished"
  echo
  sleep 2

  echo "$(pinkb [TASK]) Adding repositories"
  installtask update $1
  echo "$(greenb [SUCCESS]) "Adding repositories" finished"
  echo
  sleep 2

  echo "$(pinkb [TASK]) Installing Java 8"
  installtask oracle-java
  echo "$(greenb [SUCCESS]) "Installing Java 8" finished"
  echo
  sleep 2

  if [[ $1 == true ]]; then
    echo "$(pinkb [TASK]) Installing MariaDB"
    installtask mariadb
    echo "$(greenb [SUCCESS]) "Installing MariaDB" finished"
  else
    echo "$(greenb [SUCCESS]) "Skipping MariaDB" installation"
  fi
  echo
  sleep 2

  echo "$(pinkb [TASK]) Installing Spigot"
  installtask spigot
  echo "$(greenb [SUCCESS]) "Installing Spigot" finished"
  echo
  sleep 2

  echo "$(pinkb [TASK]) Restarting Services"
  installtask restart
  echo "$(greenb [SUCCESS]) "Restarting Services" finished"
  echo
  sleep 2
  echo "Detailed log in ./spigot.log"
}