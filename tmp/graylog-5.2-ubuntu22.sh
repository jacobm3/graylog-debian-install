#!/bin/bash
set -e

# https://go2docs.graylog.org/5-2/downloading_and_installing_graylog/ubuntu_installation.html

# graylog wants everything in UTC
sudo timedatectl set-timezone UTC

# mongo
wget -qO- 'http://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf5679a222c647c87527c2f8cb00a0bd1e2c63c11' | sudo apt-key add -
sudo systemctl daemon-reload
sudo systemctl enable mongod.service
sudo systemctl restart mongod.service
sudo systemctl --type=service --state=active | grep mongod

# opensearch
curl -o- https://artifacts.opensearch.org/publickeys/opensearch.pgp | sudo gpg --dearmor --batch --yes -o /usr/share/keyrings/opensearch-keyring
echo "deb [signed-by=/usr/share/keyrings/opensearch-keyring] https://artifacts.opensearch.org/releases/bundle/opensearch/2.x/apt stable main" | sudo tee /etc/apt/sources.list.d/opensearch-2.x.list
sudo apt-get update
sudo apt-get install opensearch

cp /etc/opensearch/opensearch.yml /etc/opensearch/opensearch.yml.dist
cat > /etc/opensearch/opensearch.yml <<EOF
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
cp /etc/opensearch/jvm.options /etc/opensearch/jvm.options.dist
cat > /etc/opensearch/jvm.options <<EOF
-Xms1g
-Xmx1g
EOF

sudo sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' >> sudo /etc/sysctl.conf

sudo systemctl daemon-reload
sudo systemctl enable opensearch.service
sudo systemctl start opensearch.service
sudo systemctl status opensearch.service

# graylog
wget https://packages.graylog2.org/repo/packages/graylog-5.2-repository_latest.deb
sudo dpkg -i graylog-5.2-repository_latest.deb
sudo apt-get update && sudo apt-get install graylog-server 


