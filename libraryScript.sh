#!/bin/bash

# Install 
#   Rancher Kubernetes Engine Agent
function InstallRKE2Agent(){

    echo "InstallRKE2Agent - Rancher Kubernetes Engine"

    # we add INSTALL_RKE2_TYPE=agent
    curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=agent sh -

    # create config file
    mkdir -p /etc/rancher/rke2/

    # change the ip to reflect your rancher1 ip
    echo "server: https://192.168.50.85:9345" > /etc/rancher/rke2/config.yaml

    # change the Token to the one from rancher1 /var/lib/rancher/rke2/server/node-token
    echo "token: $TOKEN" >> /etc/rancher/rke2/config.yaml

    # enable and start
    systemctl enable rke2-agent.service
    systemctl start rke2-agent.service

}

# Install 
#   Rancher Kubernetes Engine 2
function InstallRKE2(){

    echo "InstallRKE2 - Rancher Kubernetes Engine"
    sudo curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=server sh -

    # start and enable for restarts -
    systemctl enable rke2-server.service
    systemctl start rke2-server.service

    # simlink all the things - kubectl
    ln -s $(find /var/lib/rancher/rke2/data/ -name kubectl) /usr/local/bin/kubectl
    
    # add kubectl conf
    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

    # check node status
    kubectl  get node

}
# Install 
#   NFS
function InstallNFS(){

    echo 'InstallNFS'

    # Ubuntu instructions
    # stop the software firewall
    # systemctl stop ufw
    # systemctl disable ufw

    # get updates, install nfs, and apply
    sudo apt install nfs-common -y

    # clean up
    sudo apt autoremove -y

}

# Update 
#   System
function UpdateSystem()
{
    echo 'UpdateSystem'

	#Atualizar o Ubuntu
    sudo apt update
    sudo apt upgrade -y
}

# Install 
#   Docker
function InstallDocker() {

	echo 'InstallDocker'

	#Uninstall or delete older versions of Docker
	sudo apt remove -y docker docker-engine docker.io containerd runc
	
	#install Docker
	sudo apt install -y docker.io 

	#In addition, add the currently logged-in user to the Docker group to enable them to run Docker commands without sudo privileges.
	sudo usermod -aG docker $USER

	#Then activate the changes to groups.
	newgrp docker

	#start and enable the Docker daemon.
	sudo systemctl start docker
	
	#Service starts every time during system startup.
	sudo systemctl enable docker
}

# Install 
#   Rancher
function InstallRancher()
{
	echo 'InstallRancher'

    # on the server rancher1
    # add helm
    curl -#L https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # add needed helm charts
    helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
    helm repo add jetstack https://charts.jetstack.io

    # still on  rancher1
    # add the cert-manager CRD
    kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.crds.yaml

    # helm install jetstack
    helm upgrade -i cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace

    # helm install rancher
    helm upgrade -i rancher rancher-latest/rancher --create-namespace --namespace cattle-system --set hostname=rancher.dockr.life --set bootstrapPassword=bootStrapAllTheThings --set replicas=1

}

# Install 
#   Portainer
function InstallPortainer()
{
	echo 'InstallPortainer'
	sudo docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:2.9.3

	echo 'Restart portainer'
	sudo docker restart portainer
}

# Config
#   SSH
function ConfigSSH()
{
    echo 'ConfigSSH--'
    addUserAccount "Alfredo"
    disableSudoPassword "Alfredo"
    addSSHKey "Alfredo" "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8XKMCa9s1gryPgnIirnUeYUtb5RVrc+s9usVWwZLQm3bmeKdT6w3OvYc03HrPprHJbiHzonfIEdk+r4RlqpKHTusu5sA8av250B2hgSNXFx9LKO+dow1LJsMslH5Jfd8ILfC082TBYF02JLo/la7QushMfrisMxOy0GFkEan3ujoF0wtdaitTtEXFMATkRCWKLvjIAL5qKperD2C2rG5kiy5OhUEImcrbMZfJfcqSS94f/s6Le46nQh9AbtncWCfTmnBKH2tIC6+mzgPw6qAVn8Uo6QHlvaX0DrcxbglKWVX+RA4VjWHhSQ4xD0qH8iJz4ukVoy1BY9zhx/MRTCcyo/dB4DVT3xsLgc5jx/NrxhaHmUkGnHdpgDZIY9RCMv+y/2yUl0yK4s41Bum+AqFpXLbUu36CxgOhH/WrwYDQIU/t5IKJPEjZg5quvwynn07Q3jbeArEMsMMpeIkVsXAqCVgz6g3/ID1I+3ixwFBv5b3EDwvbnaiN2Vy1lrng9OMl4epAOmz+3WteQMDbbu6aJ/TSzqE/T3EaAIDmn2RStwtjyb0s7Agn1aabSQMidnQ74BxX7k0K5omPd0r0HNRYQgw2JLJ3Xlhtxo2A41vRoXH+FXlUJsxfKe5Y1prNGS8Nr2yUcwEVAd8/MmAaQxX+aSWySFsTPSI37jcNxBLSeQ== rsa-key-20220814"

}

# Config
#   FireWall
function SetupFirewallDocker()
{
    #Firewall do docker.
    sudo docker run --name firewall 
    --env OPEN_PORTS="22,80,443" 
    --env ACCEPT_ALL_FROM="ip1,ip2" 
    --env CHAIN="DOCKER-FIREWALL" -itd --restart=always 
    --cap-add=NET_ADMIN 
    --net=host vitobotta/docker-firewall:0.1.0

}

# Setup
#   Fail2Ban
function SetupFail2Ban()
{

    #Fail2ban
    sudo docker run -it -d --name fail2ban --restart always \
    --network host \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    -v $(pwd)/fail2ban:/data \
    -v /var/log:/var/log:ro \
    -e F2B_LOG_LEVEL=DEBUG \
    -e F2B_IPTABLES_CHAIN=INPUT \
    -e F2B_ACTION="%(action_mwl)s" \
    -e TZ=EEST \
    -e F2B_DEST_EMAIL=... \
    -e F2B_SENDER=... \
    -e SSMTP_HOST=... \
    -e SSMTP_PORT=... \
    -e SSMTP_USER=... \
    -e SSMTP_PASSWORD=... \
    -e SSMTP_TLS=YES \
    crazymax/fail2ban:latest
}

# Install 
#   Vi
function installVim(){
    # Vi /etc/ssh/sshd_config
    apt-get update && apt-get install -y vim
}


function SetupSSH(){
    # # Create the .ssh directory if it does not exist
    # mkdir -m 700 -p ~/.ssh

    # # Import public key
    # curl https://raw.githubusercontent.com/alfxp/s/master/public-ssh.pub >> ~/.ssh/authorized_keys
    
    # # Fix permissions
    # chmod 600 ~/.ssh/authorized_keys

    # sudo sed -ri 's/#?ListenAddress\s.*$/ListenAddress ?????/' /etc/ssh/sshd_config 

    sudo sed -ri 's/#?Ports\s.*$/Ports 4422/' /etc/ssh/sshd_config
    sudo sed -ri 's/#?StrictModes\s.*$/StrictModes yes/' /etc/ssh/sshd_config
    sudo sed -ri 's/#?ServerKeyBits\s.*$/ServerKeyBits 1024/' /etc/ssh/sshd_config 
    sudo sed -ri 's/#?LoginGraceTime\s.*$/LoginGraceTime 600/' /etc/ssh/sshd_config    
    sudo sed -ri 's/#?KeyRegenerationInterval\s.*$/KeyRegenerationInterval 3600/' /etc/ssh/sshd_config 
    sudo sed -ri 's/#?PermitRootLogin\s.*$/PermitRootLogin no/' /etc/ssh/sshd_config 
    sudo sed -ri 's/#?IgnoreRhosts\s.*$/IgnoreRhosts yes/' /etc/ssh/sshd_config 
    sudo sed -ri 's/#?IgnoreUserKnownHosts\s.*$/IgnoreUserKnownHosts yes/' /etc/ssh/sshd_config     
    sudo sed -ri 's/#?PubkeyAuthentication\s.*$/PubkeyAuthentication yes/' /etc/ssh/sshd_config 
    sudo sed -ri 's/#?X11Forwarding\s.*$/X11Forwarding no/' /etc/ssh/sshd_config 
    sudo sed -ri 's/#?PrintMotd\s.*$/PrintMotd yes/' /etc/ssh/sshd_config 
    sudo sed -ri 's/#?PermitEmptyPasswords\s.*$/PermitEmptyPasswords no/' /etc/ssh/sshd_config 
    sudo sed -ri 's/#?PasswordAuthentication\s.*$/PasswordAuthentication no/' /etc/ssh/sshd_config 

    # Restart the SSH server
    sudo systemctl restart sshd
    
}
                    
