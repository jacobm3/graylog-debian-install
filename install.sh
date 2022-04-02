#!/bin/bash -e

# https://docs.graylog.org/en/4.1/pages/installation/os/debian.html

hostname=graylog-install
echo hostname | sudo tee -a /etc/hostname
echo "127.0.0.1 localhost $hostname" | sudo tee -a /etc/hosts
sudo hostname $hostname

sudo apt update && sudo apt upgrade


# Install Mongo, Elastic, Graylog
wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | sudo apt-key add -
echo "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/4.2 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list

wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/oss-7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list

sudo apt-get update
sudo apt-get install -y mongodb-org apt-transport-https openjdk-11-jre-headless \
  uuid-runtime pwgen dirmngr gnupg wget nmap xxd elasticsearch-oss

sudo systemctl daemon-reload
sudo systemctl enable mongod.service
sudo systemctl restart mongod.service
sudo systemctl --type=service --state=active | grep mongod

sudo tee -a /etc/elasticsearch/elasticsearch.yml > /dev/null <<EOT
cluster.name: graylog
action.auto_create_index: false
EOT

sudo systemctl daemon-reload
sudo systemctl enable elasticsearch.service
sudo systemctl restart elasticsearch.service
sudo systemctl restart elasticsearch.service

wget https://packages.graylog2.org/repo/packages/graylog-4.2-repository_latest.deb
sudo dpkg -i graylog-4.2-repository_latest.deb
sudo apt-get update && sudo apt-get install graylog-server graylog-integrations-plugins 


shapass=$(echo graylogInitPass123 | tr -d '\n' | sha256sum | cut -d" " -f1)
sudo sed -i "s/^root_password_sha2.*/root_password_sha2 = $shapass/" /etc/graylog/server/server.conf
sudo sed -i 's/^http_bind_address/#http_bind_address/' /etc/graylog/server/server.conf
echo 'http_bind_address = 0.0.0.0:9000' | sudo tee -a /etc/graylog/server/server.conf

passsec=$(pwgen -N 1 -s 96)
sudo sed -i "s/^password_secret.*/password_secret = $passsec/" /etc/graylog/server/server.conf


sudo systemctl daemon-reload
sudo systemctl enable graylog-server.service
sudo systemctl start graylog-server.service
sudo systemctl --type=service --state=active | grep graylog


# Install node_exporter
sudo useradd --system --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.2.2/node_exporter-1.2.2.linux-amd64.tar.gz
tar zxvf node_exporter-1.2.2.linux-amd64.tar.gz
sudo cp node_exporter-1.2.2.linux-amd64/node_exporter /usr/local/bin
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

sudo tee /etc/systemd/system/node_exporter.service <<"EOF"
[Unit]
Description=Node Exporter

[Service]
User=node_exporter
Group=node_exporter
EnvironmentFile=-/etc/sysconfig/node_exporter
ExecStart=/usr/local/bin/node_exporter $OPTIONS

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && \
sudo systemctl start node_exporter && \
sudo systemctl status node_exporter && \
sudo systemctl enable node_exporter

