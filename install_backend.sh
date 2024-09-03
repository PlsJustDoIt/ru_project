#!/bin/bash

source ~/.nvm/nvm.sh
## Installation of mongodb

sudo apt-get install gnupg curl -y

curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
   --dearmor

UBUNTU_CODENAME=jammy
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu $UBUNTU_CODENAME/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt update
sudo apt install -y mongodb-org
sudo systemctl enable mongod.service # or sudo service mongod start

### Check for installation of nvm
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    source ~/.bashrc
else 
    echo "nvm already installed"
fi

### Install nodejs
nvm current
nvm install --lts
nvm use --lts


### Install backend dependencies

cd backend
npm install
