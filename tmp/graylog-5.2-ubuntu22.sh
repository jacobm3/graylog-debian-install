#!/bin/bash
set -e

# curl -sSL https://raw.githubusercontent.com/jacobm3/graylog-debian-install/main/tmp/graylog-5.2-ubuntu22.sh | bash

# https://go2docs.graylog.org/5-2/downloading_and_installing_graylog/ubuntu_installation.html

# graylog wants everything in UTC
sudo timedatectl set-timezone UTC

# mongo
wget -qO- 'http://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf5679a222c647c87527c2f8cb00a0bd1e2c63c11' | sudo apt-key add -

# https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-ubuntu/
sudo apt-get install gnupg curl
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
   --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org

sudo systemctl daemon-reload
sudo systemctl enable mongod.service
sudo systemctl restart mongod.service
sudo systemctl --type=service --state=active --no-pager | grep mongod

# opensearch
curl -o- https://artifacts.opensearch.org/publickeys/opensearch.pgp | sudo gpg --dearmor --batch --yes -o /usr/share/keyrings/opensearch-keyring
echo "deb [signed-by=/usr/share/keyrings/opensearch-keyring] https://artifacts.opensearch.org/releases/bundle/opensearch/2.x/apt stable main" | sudo tee /etc/apt/sources.list.d/opensearch-2.x.list
sudo apt-get update
sudo apt-get install opensearch

sudo cp /etc/opensearch/opensearch.yml /etc/opensearch/opensearch.yml.dist
sudo tee /etc/opensearch/opensearch.yml <<EOF
cluster.name: graylog
node.name: ${HOSTNAME}
path.data: /var/lib/opensearch
path.logs: /var/log/opensearch
discovery.type: single-node
network.host: 0.0.0.0
action.auto_create_index: false
plugins.security.disabled: true
EOF

# memory tuning
sudo cp /etc/opensearch/jvm.options /etc/opensearch/jvm.options.dist
sudo tee /etc/opensearch/jvm.options <<EOF
-Xms1g
-Xmx1g
EOF

sudo sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' >> sudo /etc/sysctl.conf

sudo systemctl daemon-reload
sudo systemctl enable opensearch.service
sudo systemctl start opensearch.service
sudo systemctl status --no-pager opensearch.service

# graylog
wget https://packages.graylog2.org/repo/packages/graylog-5.2-repository_latest.deb
sudo dpkg -i graylog-5.2-repository_latest.deb
# sudo apt-get update && sudo apt-get install graylog-server=5.2.1-1 
sudo apt-get update && sudo apt-get install graylog-server

sudo cp /etc/graylog/server/server.conf /etc/graylog/server/server.conf.dist
# SEC=$(< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c${1:-96} | head -1 </dev/stdin | tr -d '\n' | sha256sum | cut -d" " -f1)
SEC1=$(< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c${1:-96})
SEC2=$(echo $SEC1 | head -1 </dev/stdin | tr -d '\n' | sha256sum | cut -d" " -f1)
echo $SEC1 | sudo tee /root/sec1.txt
echo $SEC2 | sudo tee /root/sec2.txt
sudo sed -i "s/^password_secret/password_secret = $SEC2/" /etc/graylog/server/server.conf
sudo sed -i '/^[^#]*http_bind_address/s/^/#/' /etc/graylog/server/server.conf
echo 'http_bind_address = 0.0.0.0:9000' | sudo tee -a /etc/graylog/server/server.conf
echo 'elasticsearch_hosts = http://localhost:9200' | sudo tee -a /etc/graylog/server/server.conf

sudo systemctl daemon-reload
sudo systemctl enable graylog-server.service
sudo systemctl start graylog-server.service
sudo systemctl --type=service --state=active --no-pager | grep graylog
