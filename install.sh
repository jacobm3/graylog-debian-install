#!/bin/bash -e

# https://docs.graylog.org/en/4.1/pages/installation/os/debian.html

sudo apt update && sudo apt upgrade


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

wget https://packages.graylog2.org/repo/packages/graylog-4.1-repository_latest.deb
sudo dpkg -i graylog-4.1-repository_latest.deb
sudo apt-get update && sudo apt-get install graylog-server graylog-integrations-plugins 





