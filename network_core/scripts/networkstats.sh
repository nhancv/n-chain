#!/bin/bash
# Install aws cli
apt update -y
apt install unzip -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Increase open files
ulimit -S -n 64000
# Installing jemalloc to reduce memory usage
apt -y install libjemalloc-dev

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

# Install grunt
npm install -g grunt-cli

# INSTALL AS USER ROLE
cat <<'EOT' >> /tmp/app.sh
#!/bin/bash
cd /home/ubuntu

# INSTALL APPLICATION
export PROJECT_ENV="$ENV"
export ETHSTATS_SECRET="$ETHSTATS_SECRET"

## Install ethstats server
git clone https://github.com/goerli/ethstats-server.git
cd ethstats-server
npm install
grunt poa
WS_SECRET="${ETHSTATS_SECRET}" pm2 --name ethstats-server start npm -- run start --cron-restart "0 * * * *"


## PM2 auto start
pm2 save
pm2 startup

EOT

export ENV="${ENV}"
export ETHSTATS_SECRET="${ETHSTATS_SECRET}"
chown $EC2_USER.$EC2_USER /tmp/app.sh
chmod u+x /tmp/app.sh
sudo -u $EC2_USER ENV=$ENV ETHSTATS_SECRET=$ETHSTATS_SECRET /tmp/app.sh
