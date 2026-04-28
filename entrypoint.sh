#!/usr/bin/bash
set -e
umask 002

setup_user() {
  if [ -n "$GID" ] && ! getent group "$GID" > /dev/null 2>&1; then
    addgroup --gid "$GID" user
    echo "** Group 'user' created with GID ${GID}"
  fi

  if [ -n "$DOCKER_GID" ] && ! getent group "$DOCKER_GID" > /dev/null 2>&1; then
    addgroup -gid "$DOCKER_GID" docker-host
    echo "** Group 'docker-host' created with GID ${DOCKER_GID}"
  fi

  if [ -n "$UID" ] && ! getent passwd "$UID" > /dev/null 2>&1; then 
    local group_name
    group_name=$(getent group "$GID" | cut -d: -f1)
    adduser --gecos "" --disabled-password --uid "${UID}" --gid "${GID}" "user"
    echo "** User 'user' created with UID ${UID}"
  fi
}

setup_shell() {
  local user="$1"
  local bashrc="/home/${user}/.bashrc"

  {
    echo "PS1='\\[\\e[38;5;5m\\]\\[\\e[1m\\](claude)\\[\\e[m\\] \\[\\e[34m\\]\\[\\e[1m\\]\\W\\[\\e[m\\] \\$ \\033[0m'"
    echo "alias ll='ls -al'"

    # Proxy settings
    [ -z "$NO_PROXY" ] || echo "export NO_PROXY=\"${NO_PROXY}\"";
    [ -z "$HTTP_PROXY" ] || echo "export HTTP_PROXY=\"${HTTP_PROXY}\"";
    [ -z "$HTTPS_PROXY" ] || echo "export HTTPS_PROXY=\"${HTTPS_PROXY}\"";
    [ -z "$no_proxy" ] || echo "export no_proxy=\"${no_proxy}\"";
    [ -z "$http_proxy" ] || echo "export http_proxy=\"${http_proxy}\"";
    [ -n "$https_proxy" ] || echo "export https_proxy=\"${https_proxy}\"";
  } > "$bashrc"
}

add_group_by_gid() {
  local user="$1"
  local gid="$2"
  usermod -aG "$(getent group "${gid}" | cut -d: -f1)" "$user"
}

setup_user
USER=$(getent passwd "${UID}" | cut -d: -f1)

add_group_by_gid "$USER" "$GID"
add_group_by_gid "$USER" "$DOCKER_GID"

setup_shell "$USER"

su -l "$USER" -s /bin/bash -c " \
  cd $PWD || exit 1
  PATH=:~/.local/bin:$PATH
  exec $*
"
