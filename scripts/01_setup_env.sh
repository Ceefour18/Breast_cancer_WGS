#!/bin/bash
set -e

echo "========================================="
echo "STEP 1: Updating System Packages..."
echo "========================================="
sudo apt-get update -y && sudo apt-get upgrade -y

echo "========================================="
echo "STEP 2: Installing Docker Engine..."
echo "========================================="
sudo apt-get install -y ca-certificates curl gnupg lsb-release tmux
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

echo "========================================="
echo "STEP 3: Creating Pipeline Directory Tree..."
echo "========================================="
mkdir -p data/ref data/tumor data/normal data/output

echo "========================================="
echo "STEP 4: Pulling Broad Institute GATK4 Image..."
echo "========================================="
sudo docker pull broadinstitute/gatk:4.6.0.0

echo "========================================="
echo "ENVIRONMENT SETUP COMPLETE!"
echo "========================================="
echo "Please log out of the server and log back in to apply Docker permissions."
