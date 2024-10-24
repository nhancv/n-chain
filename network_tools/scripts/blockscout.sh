#!/bin/bash
# Install aws cli
apt update -y
apt install unzip -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
export EC2_USER=ubuntu

# Install docker
curl -sSL https://get.docker.com | sh
usermod -aG docker $EC2_USER

# Increase open files
ulimit -S -n 64000
# Installing jemalloc to reduce memory usage
apt -y install libjemalloc-dev

# INSTALL AS USER ROLE
cat <<'EOT' >> /tmp/app.sh
#!/bin/bash
cd /home/ubuntu

# INSTALL APPLICATION
export PROJECT_ENV="$ENV"
export BLOCKSCOUT_RPC="$BLOCKSCOUT_RPC"
export BLOCKSCOUT_CHAINID="$BLOCKSCOUT_CHAINID"
export BLOCKSCOUT_URL="$BLOCKSCOUT_URL"

# Extract the protocol
RPC_PROTOCOL=$(echo $BLOCKSCOUT_RPC | sed -E 's|^(https?)://.*|\1|')
# Extract the host
RPC_HOST=$(echo $BLOCKSCOUT_RPC | sed -E 's|^https?://([^/]+).*|\1|')

# Clone source
REPO_URL="https://github.com/blockscout/blockscout.git"
REPO_DIR=".blockscout_all"
git clone "$REPO_URL" $REPO_DIR
cd $REPO_DIR/docker-compose

# Deploy
# Update common envs: https://github.com/blockscout/blockscout/blob/master/docker-compose/envs/common-blockscout.env
COMMON_CONFIG="envs/common-blockscout.env"
sed -i "s|ETHEREUM_JSONRPC_VARIANT=geth|ETHEREUM_JSONRPC_VARIANT=besu|g" $COMMON_CONFIG
sed -i "s|http://host.docker.internal:8545/|${BLOCKSCOUT_RPC}|g" $COMMON_CONFIG
sed -i "s|# INDEXER_DISABLE_BLOCK_REWARD_FETCHER=|INDEXER_DISABLE_BLOCK_REWARD_FETCHER=true|g" $COMMON_CONFIG

# Stats
STATS_CONFIG="envs/common-stats.env"
#printf '\nSTATS__IGNORE_BLOCKSCOUT_API_ABSENCE=true' >> $STATS_CONFIG
printf '\nSTATS__BLOCKSCOUT_API_URL=http://backend:4000' >> $STATS_CONFIG

# User ops
USEROPS_CONFIG="envs/common-user-ops-indexer.env"
sed -i "s|USER_OPS_INDEXER__INDEXER__REALTIME__ENABLED=true|USER_OPS_INDEXER__INDEXER__REALTIME__ENABLED=false|g" $USEROPS_CONFIG
sed -i "s|USER_OPS_INDEXER__INDEXER__RPC_URL=\"\"|USER_OPS_INDEXER__INDEXER__RPC_URL=\"${BLOCKSCOUT_RPC}\"|g" $USEROPS_CONFIG

# Disable ads
FRONTEND_CONFIG="envs/common-frontend.env"
sed -i "s|NEXT_PUBLIC_NETWORK_ID=5|NEXT_PUBLIC_NETWORK_ID=${BLOCKSCOUT_CHAINID}|g" $FRONTEND_CONFIG
sed -i "s|NEXT_PUBLIC_API_HOST=localhost|NEXT_PUBLIC_API_HOST=${BLOCKSCOUT_URL}|g" $FRONTEND_CONFIG
sed -i "s|NEXT_PUBLIC_API_PROTOCOL=http|NEXT_PUBLIC_API_PROTOCOL=https|g" $FRONTEND_CONFIG
sed -i "s|NEXT_PUBLIC_APP_HOST=localhost|NEXT_PUBLIC_APP_HOST=${BLOCKSCOUT_URL}|g" $FRONTEND_CONFIG
sed -i "s|NEXT_PUBLIC_APP_PROTOCOL=http|NEXT_PUBLIC_APP_PROTOCOL=https|g" $FRONTEND_CONFIG
sed -i "s|NEXT_PUBLIC_API_WEBSOCKET_PROTOCOL=ws|NEXT_PUBLIC_API_WEBSOCKET_PROTOCOL=wss|g" $FRONTEND_CONFIG
printf '\nNEXT_PUBLIC_AD_BANNER_PROVIDER=none' >> $FRONTEND_CONFIG
printf '\nNEXT_PUBLIC_AD_TEXT_PROVIDER=none' >> $FRONTEND_CONFIG

# Update environment variables in the docker-compose.yml file
APP_CONFIG="docker-compose.yml"
sed -i "s|http://host.docker.internal:8545/|${BLOCKSCOUT_RPC}|g" $APP_CONFIG
sed -i "s|ETHEREUM_JSONRPC_TRACE_URL: ${BLOCKSCOUT_RPC}|INDEXER_DISABLE_INTERNAL_TRANSACTIONS_FETCHER: 'true'|g" $APP_CONFIG
sed -i "s|ETHEREUM_JSONRPC_WS_URL: ws://host.docker.internal:8545/|INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER: 'true'|g" $APP_CONFIG
sed -i "s|CHAIN_ID: '1337'|CHAIN_ID: '${BLOCKSCOUT_CHAINID}'|g" $APP_CONFIG

# Start blockscout
docker compose -f $APP_CONFIG up -d

echo "Blockscout is running at http://localhost:80"

EOT

export ENV="${ENV}"
export BLOCKSCOUT_RPC="${BLOCKSCOUT_RPC}"
export BLOCKSCOUT_CHAINID="${BLOCKSCOUT_CHAINID}"
export BLOCKSCOUT_URL="${BLOCKSCOUT_URL}"
chown $EC2_USER.$EC2_USER /tmp/app.sh
chmod u+x /tmp/app.sh
sudo -u $EC2_USER ENV=$ENV BLOCKSCOUT_RPC=$BLOCKSCOUT_RPC BLOCKSCOUT_CHAINID=$BLOCKSCOUT_CHAINID BLOCKSCOUT_URL=$BLOCKSCOUT_URL /tmp/app.sh
