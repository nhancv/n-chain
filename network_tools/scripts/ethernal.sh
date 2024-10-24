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
# Install parse JSON tool
apt install jq -y

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

# Install ethernal cli
npm install -g ethernal

# INSTALL AS USER ROLE
cat <<'EOT' >> /tmp/app.sh
#!/bin/bash
cd /home/ubuntu

# INSTALL APPLICATION
export PROJECT_ENV="$ENV"
export ETHERNAL_USER="$ETHERNAL_USER"
export ETHERNAL_PASSWORD="$ETHERNAL_PASSWORD"

# Clone source
git clone https://github.com/nhancv/ethernal.git
cd ethernal

# Fetch network config
echo "$(aws secretsmanager --output text get-secret-value --secret-id testnet-nchaintools-ethernal@env --query SecretString --region us-east-1)" > .env.prod

# Deploy
docker compose -f docker-compose.prod.yml up -d --wait
# Wait for web up
while ! nc -z localhost 8888; do sleep 1; done;
# Migrate database
sleep 10
docker exec -d web npx sequelize db:create
sleep 30
docker exec -d web npx sequelize db:migrate
sleep 30

# Credential
export CREDENTIAL='{"email":"${ETHERNAL_USER}","password":"${ETHERNAL_PASSWORD}"}'
# Register admin account and extract api token
export API_TOKEN=$(curl -s -d "$CREDENTIAL" -H "Content-Type: application/json" -X POST http://localhost:8888/api/users/signup | jq -r '.user.apiToken')

# Custom public explorer
cd ..
mkdir ethernal-custom && cd ethernal-custom
npm init -y
npm install axios
echo "$(aws secretsmanager --output text get-secret-value --secret-id testnet-nchaintools-ethernal@index --query SecretString --region us-east-1)" > index.js
node index.js $API_TOKEN

# Install worker to sync data to ethernal
cd ../ethernal
ETHERNAL_EMAIL=$ETHERNAL_USER ETHERNAL_PASSWORD=$ETHERNAL_PASSWORD ETHERNAL_API_ROOT=http://localhost:8888 pm2 start ethernal --name "ethernal-explorer" -- listen -s -w "Explorer"

EOT

export ENV="${ENV}"
export ETHERNAL_USER="${ETHERNAL_USER}"
export ETHERNAL_PASSWORD="${ETHERNAL_PASSWORD}"
chown $EC2_USER.$EC2_USER /tmp/app.sh
chmod u+x /tmp/app.sh
sudo -u $EC2_USER ENV=$ENV ETHERNAL_USER=$ETHERNAL_USER ETHERNAL_PASSWORD=$ETHERNAL_PASSWORD /tmp/app.sh
