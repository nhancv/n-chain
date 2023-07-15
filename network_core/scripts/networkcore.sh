#!/bin/bash
# Install aws cli
apt -y update
apt -y install unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Install java 17
apt -y install openjdk-17-jdk openjdk-17-jre

# Increase open files
ulimit -S -n 64000

# Installing jemalloc to reduce memory usage
apt -y install libjemalloc-dev

# Install Besu
export BESU_VERSION=23.4.1
export BESU_DIR=besu-$BESU_VERSION
wget https://hyperledger.jfrog.io/hyperledger/besu-binaries/besu/$BESU_VERSION/besu-$BESU_VERSION.tar.gz
sudo tar xvzf $BESU_DIR.tar.gz
cd $BESU_DIR && sudo ln -s $(pwd)/bin/besu /usr/bin/besu

export EC2_USER=ubuntu
# Install node, npm, yarn, pm2
apt update -y
curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt install nodejs -y
npm install yarn -g
npm install pm2 -g
sudo -u $EC2_USER pm2 install pm2-logrotate
sudo -u $EC2_USER pm2 set pm2-logrotate:max_size 10M
sudo -u $EC2_USER pm2 set pm2-logrotate:compress true
sudo -u $EC2_USER pm2 set pm2-logrotate:retain 10

# INSTALL AS USER ROLE
cat <<'EOT' >> /tmp/app.sh
#!/bin/bash
cd /home/ubuntu

mkdir -p network/data
cd network

# Fetch network config
echo "$(aws secretsmanager --output text get-secret-value --secret-id testnet-nchaincore-genesis --query SecretString --region us-east-1)" > genesis.json
echo "$(aws secretsmanager --output text get-secret-value --secret-id testnet-nchaincore-nodeconf --query SecretString --region us-east-1)" > nodeconf.toml

# Fetch node raw key data and decrypt
git clone https://github.com/nhancv/aes-decrypt.git
export ETHSTATS_SECRET="$ETHSTATS_SECRET"
export ETHSTATS_PUSH="$ETHSTATS_PUSH"
export KEY="$ENCRYPT_KEY"
export NODE_ID="$NODE_ID"
export NODE_KEY_FILE="testnet-nchaincore-node${NODE_ID}-key"
export DATA_ENCRYPT=$(aws secretsmanager --output text get-secret-value --secret-id $NODE_KEY_FILE --query SecretString --region us-east-1)
node aes-decrypt/index $DATA_ENCRYPT $KEY > data/key

# Start Besu
pm2 --name "node${NODE_ID}" start "besu --config-file=./nodeconf.toml --ethstats=Node-${NODE_ID}:${ETHSTATS_SECRET}@${ETHSTATS_PUSH}:3000"

## PM2 auto start
pm2 save
pm2 startup

# Reload node to make sure all nodes connection via dns domain
sleep $(($NODE_ID*30))
for i in {1..3}; do sleep 60s && pm2 reload "node${NODE_ID}"; done

EOT

export ENV="${ENV}"
export NODE_ID="${NODE_ID}"
export ENCRYPT_KEY="${ENCRYPT_KEY}"
export ETHSTATS_SECRET="${ETHSTATS_SECRET}"
export ETHSTATS_PUSH="${ETHSTATS_PUSH}"
chown $EC2_USER.$EC2_USER /tmp/app.sh
chmod u+x /tmp/app.sh
sudo -u $EC2_USER ENV=$ENV NODE_ID=$NODE_ID ENCRYPT_KEY=$ENCRYPT_KEY ETHSTATS_SECRET=$ETHSTATS_SECRET ETHSTATS_PUSH=$ETHSTATS_PUSH /tmp/app.sh
