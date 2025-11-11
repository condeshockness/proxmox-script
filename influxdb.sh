#!/usr/bin/env bash


# Source: https://www.influxdata.com/

msg_ok() {
    echo -e "\e[32m[OK]\e[0m $1"
}

msg_info "Installing Dependencies"
$STD apt-get install -y lsb-base
$STD apt-get install -y lsb-release
msg_ok "Installed Dependencies"

msg_info "Setting up InfluxDB Repository"



# Add the InfluxData key to verify downloads and add the repository
curl --silent --location -O https://repos.influxdata.com/influxdata-archive.key
gpg --show-keys --with-fingerprint --with-colons ./influxdata-archive.key 2>&1 \
| grep -q '^fpr:\+24C975CBA61A024EE1B631787C3D57159FC2F927:$' \
&& cat influxdata-archive.key \
| gpg --dearmor \
| tee /etc/apt/keyrings/influxdata-archive.gpg > /dev/null \
&& echo 'deb [signed-by=/etc/apt/keyrings/influxdata-archive.gpg] https://repos.influxdata.com/debian stable main' \
| tee /etc/apt/sources.list.d/influxdata.list

msg_ok "Set up InfluxDB Repository"

msg_info "Installing InfluxDB"
$STD apt-get update

$STD apt-get install -y influxdb2

$STD systemctl enable --now influxdb

msg_ok "Installed InfluxDB"

read -r -p "${TAB3}Would you like to add Telegraf? <y/N> " prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
  msg_info "Installing Telegraf"
  $STD apt-get install -y telegraf
  msg_ok "Installed Telegraf"
fi

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"