#  Create KVM guest VM on fedora WSL

## requirements

KVM guest directory: /mnt/d/kvm  
KVM guest images : /mnt/d/kvm/images  

Download images:
````
# cd /mnt/d/kvm/images
# wget https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-LVM.latest.x86_64.qcow2
# wget https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2
````

## cloud-init for Rocky9 and Debian13

````
# bash create-kvm-guest.sh

````

output:
````

╔══════════════════════════════════════╗
║   Création d'une VM KVM cloud-init   ║
╚══════════════════════════════════════╝

Nom de la VM (ex: lit001) : lit007

  OS disponibles :
  1) Rocky Linux 9  (osinfo: rocky9)
  2) Debian 13      (osinfo: debian13)

Choix OS [1/2] : 1

Adresse IP (ex: 192.168.124.11) : 192.168.124.17
Masque CIDR (ex: 24) : 24
Gateway    (ex: 192.168.124.1) : 192.168.124.1
DNS        (ex: 10.255.255.254) : 10.255.255.254
Search domain [kvm.local] : kvm.local

vCPUs  [2] : 2
RAM (MiB) [2048] : 2048

Mot de passe root/cloud [abc123!] : abc123!

╔══════════════════════════════════════════════╗
║                  Récapitulatif               ║
╚══════════════════════════════════════════════╝
  VM         : lit007
  OS         : Rocky Linux 9  (osinfo: rocky9)
  Image      : Rocky-9-GenericCloud-LVM.latest.x86_64.qcow2
  Répertoire : /mnt/d/kvm/lit007
  IP         : 192.168.124.17/24  gw=192.168.124.1  dns=10.255.255.254  iface=eth0
  Search     : kvm.local
  vCPUs      : 2   RAM: 2048 MiB

Confirmer la création ? [o/N] : o

````

