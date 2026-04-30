#!/usr/bin/env bash
set -e
umask 002

# Use existing USERNAME from env or default to "claude"
USERNAME="${USERNAME:-claude}"

# Validate required environment variables
validate_required_vars() {
  if [ -z "$HOST_UID" ]; then
    echo "ERROR: HOST_UID environment variable is required"
    exit 1
  fi

  if [ -z "$HOST_GID" ]; then
    echo "ERROR: HOST_GID environment variable is required"
    exit 1
  fi
}

# Setup user with specified UID/GID
setup_user() {
  local username="$1"

  # Create group for HOST_GID if it doesn't exist
  if ! getent group "$HOST_GID" > /dev/null 2>&1; then
    local group_name="$username"
    if getent group "$username" > /dev/null 2>&1; then
      group_name="user-host"
    fi
    addgroup --gid "$HOST_GID" "$group_name"
    echo "Group '${group_name}' created with GID ${HOST_GID}"
  fi

  # Create group for DOCKER_GID if it doesn't exist
  if [ -n "$DOCKER_GID" ] && [ "$DOCKER_GID" != "$HOST_GID" ] && ! getent group "$DOCKER_GID" > /dev/null 2>&1; then
    addgroup --gid "$DOCKER_GID" docker-host
    echo "Group 'docker-host' created with GID ${DOCKER_GID}"
  fi

  # Check if user with this UID already exists
  if getent passwd "$HOST_UID" > /dev/null 2>&1; then
    local existing_user
    local existing_home
    existing_user=$(getent passwd "$HOST_UID" | cut -d: -f1)
    existing_home=$(getent passwd "$HOST_UID" | cut -d: -f6)

    # Kill user processes if any
    pkill -u "$existing_user" 2>/dev/null || true

    # Rename user if different
    if [ "$existing_user" != "$username" ]; then
      usermod -l "$username" "$existing_user"
      echo "Renamed user from '${existing_user}' to '${username}'"
    fi

    # Change home directory if different
    local target_home="/home/${username}"
    if [ "$existing_home" != "$target_home" ]; then
      usermod -d "$target_home" -m "$username" 2>/dev/null || usermod -d "$target_home" "$username"
      echo "Changed home directory to ${target_home}"
    fi
  else
    # Create new user
    adduser --gecos "" --disabled-password \
      --uid "$HOST_UID" \
      --gid "$HOST_GID" \
      --home "/home/${username}" \
      "$username"
    echo "User '${username}' created with UID ${HOST_UID}"
  fi

  # Add user to groups
  local primary_group
  primary_group=$(getent group "$HOST_GID" | cut -d: -f1)
  if [ -n "$primary_group" ]; then
    usermod -aG "$primary_group" "$username"
    echo "Added '${username}' to group '${primary_group}'"
  fi

  if [ -n "$DOCKER_GID" ]; then
    local docker_group
    docker_group=$(getent group "$DOCKER_GID" | cut -d: -f1)
    if [ -n "$docker_group" ]; then
      usermod -aG "$docker_group" "$username"
      echo "Added '${username}' to group '${docker_group}'"
    fi
  fi
}

# Setup bashrc
setup_shell() {
  local user="$1"
  local bashrc="/home/${user}/.bashrc"

  # Create home directory if it doesn't exist
  mkdir -p "/home/${user}"
  chown "${user}:${HOST_GID}" "/home/${user}" 2>/dev/null || true

  # Ensure login shells source .bashrc — needed for renamed users who may not
  # have a .profile from skel that does this.
  local profile="/home/${user}/.profile"
  if ! grep -q '\.bashrc' "$profile" 2>/dev/null; then
    echo '[ -f ~/.bashrc ] && . ~/.bashrc' >> "$profile"
  fi

  # Overwrites .bashrc on every start by design — replaces the default .bashrc
  # created by adduser/skel with container-specific prompt and aliases.
  {
    echo "PS1='\\[\\e[38;5;5m\\]\\[\\e[1m\\](${user})\\[\\e[m\\] \\[\\e[34m\\]\\[\\e[1m\\]\\W\\[\\e[m\\] \\$ \\033[0m'"
    echo "alias ll='ls -al'"
    echo "alias la='ls -la'"
    echo "alias l='ls -cf'"
    echo "alias ..='cd ..'"
    echo "alias ...='cd ../..'"
    echo "export PATH=\$HOME/.local/bin:\$PATH"
  } > "$bashrc"

  echo "Shell configuration written to ${bashrc}"
}

# Main function
main() {
  validate_required_vars

  echo "Setting up user: ${USERNAME} (UID: ${HOST_UID}, GID: ${HOST_GID})"

  setup_user "$USERNAME"
  setup_shell "$USERNAME"

  # Execute command or shell
  if [ $# -eq 0 ]; then
    echo "Starting interactive shell for user: ${USERNAME}"
    exec su -l "$USERNAME" -s /bin/bash
  else
    echo "Executing command as user ${USERNAME}: $*"
    exec su -l "$USERNAME" -s /bin/bash -c "
      cd $PWD || exit 1
      export PATH=~/.local/bin:$PATH
      exec $*
    "
  fi
}

main "$@"