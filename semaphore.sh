#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: ramon


# This function displays an informational message with logging support.
declare -A MSG_INFO_SHOWN
SPINNER_ACTIVE=0
SPINNER_PID=""
SPINNER_MSG=""

trap 'stop_spinner' EXIT INT TERM HUP

start_spinner() {
  local msg="$1"
  local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  local spin_i=0
  local interval=0.1

  SPINNER_MSG="$msg"
  printf "\r\e[2K" >&2

  {
    while [[ "$SPINNER_ACTIVE" -eq 1 ]]; do
      printf "\r\e[2K%s %b" "${frames[spin_i]}" "${YW}${SPINNER_MSG}${CL}" >&2
      spin_i=$(((spin_i + 1) % ${#frames[@]}))
      sleep "$interval"
    done
  } &

  SPINNER_PID=$!
  disown "$SPINNER_PID"
}

stop_spinner() {
  if [[ ${SPINNER_PID+v} && -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2>/dev/null; then
    kill "$SPINNER_PID" 2>/dev/null
    sleep 0.1
    kill -0 "$SPINNER_PID" 2>/dev/null && kill -9 "$SPINNER_PID" 2>/dev/null
    wait "$SPINNER_PID" 2>/dev/null || true
  fi
  SPINNER_ACTIVE=0
  unset SPINNER_PID
}

spinner_guard() {
  if [[ "$SPINNER_ACTIVE" -eq 1 ]] && [[ -n "$SPINNER_PID" ]]; then
    kill "$SPINNER_PID" 2>/dev/null
    wait "$SPINNER_PID" 2>/dev/null || true
    SPINNER_ACTIVE=0
    unset SPINNER_PID
  fi
}

msg_info() {
  local msg="$1"
  [[ -n "${MSG_INFO_SHOWN["$msg"]+x}" ]] && return
  MSG_INFO_SHOWN["$msg"]=1

  spinner_guard
  SPINNER_ACTIVE=1
  start_spinner "$msg"
}

msg_ok() {
  local msg="$1"
  stop_spinner
  printf "\r\e[2K%s %b\n" "${CM}" "${GN}${msg}${CL}" >&2
  unset MSG_INFO_SHOWN["$msg"]
}

msg_error() {
  stop_spinner
  local msg="$1"
  printf "\r\e[2K%s %b\n" "${CROSS}" "${RD}${msg}${CL}" >&2
}

msg_info "Installing Dependencies"
$STD apt-get install -y \
  git

curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?fingerprint=on&op=get&search=0x6125E2A8C77F2818FB7BD15B93C4A3FD7BB9C367" | gpg --dearmour >/usr/share/keyrings/ansible-archive-keyring.gpg
cat <<EOF >/etc/apt/sources.list.d/ansible.list
deb [signed-by=/usr/share/keyrings/ansible-archive-keyring.gpg] http://ppa.launchpad.net/ansible/ansible/ubuntu jammy main
EOF
$STD apt update
$STD apt install -y ansible
msg_ok "Installed Dependencies"

msg_info "Setup Semaphore"
RELEASE=$(curl -fsSL https://api.github.com/repos/semaphoreui/semaphore/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
mkdir -p /opt/semaphore
cd /opt/semaphore
curl -fsSL "https://github.com/semaphoreui/semaphore/releases/download/v${RELEASE}/semaphore_${RELEASE}_linux_amd64.deb" -o "semaphore_${RELEASE}_linux_amd64.deb"
$STD dpkg -i semaphore_${RELEASE}_linux_amd64.deb

SEM_HASH=$(openssl rand -base64 32)
SEM_ENCRYPTION=$(openssl rand -base64 32)
SEM_KEY=$(openssl rand -base64 32)
SEM_PW=$(openssl rand -base64 12)
cat <<EOF >/opt/semaphore/config.json
{
  "bolt": {
    "host": "/opt/semaphore/semaphore_db.bolt"
  },
  "tmp_path": "/opt/semaphore/tmp",
  "cookie_hash": "${SEM_HASH}",
  "cookie_encryption": "${SEM_ENCRYPTION}",
  "access_key_encryption": "${SEM_KEY}"
}
EOF

$STD semaphore user add --admin --login admin --email admin@helper-scripts.com --name Administrator --password ${SEM_PW} --config /opt/semaphore/config.json
echo "${SEM_PW}" >~/semaphore.creds
echo "${RELEASE}" >"/opt/${APPLICATION}_version.txt"
msg_ok "Setup Semaphore"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/semaphore.service
[Unit]
Description=Semaphore UI
Documentation=https://docs.semaphoreui.com/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/bin/semaphore server --config /opt/semaphore/config.json
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now -q semaphore.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
rm -rf semaphore_${RELEASE}_linux_amd64.deb
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"