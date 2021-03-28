

# docker
sudo apt-get -y update

sudo apt-get -y install
sudo apt-get -y apt-transport-https
sudo apt-get -y ca-certificates
sudo apt-get -y curl
sudo apt-get -y gnupg-agent
sudo apt-get -y software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo apt-key fingerprint 0EBFCD88

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
  
sudo apt-get -y update

sudo apt-get -y install docker-ce docker-ce-cli containerd.io

sudo docker run hello-world

# docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

docker-compose --version