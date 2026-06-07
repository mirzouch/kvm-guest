#!/usr/bin/env bash
# ============================================================
#  create-kvm-guest.sh — Génération d'une VM KVM avec cloud-init
# ============================================================
set -euo pipefail

# ── Couleurs ────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Chemins de base ─────────────────────────────────────────
KVM_BASE="/mnt/d/kvm"
IMAGES_DIR="${KVM_BASE}/images"
PUBKEY_FILE="${HOME}/.ssh/id_kvm_guest.pub"

ROCKY_IMAGE="Rocky-9-GenericCloud-LVM.latest.x86_64.qcow2"
DEBIAN_IMAGE="debian-13-genericcloud-amd64.qcow2"

# ── Vérifications préalables ─────────────────────────────────
[[ -d "${IMAGES_DIR}" ]]   || error "Répertoire images introuvable : ${IMAGES_DIR}"
[[ -f "${PUBKEY_FILE}" ]]  || error "Clé publique introuvable : ${PUBKEY_FILE}"

SSH_PUBKEY=$(cat "${PUBKEY_FILE}")

# ════════════════════════════════════════════════════════════
#  Saisie interactive
# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}╔══════════════════════════════════════╗"
echo -e "║   Création d'une VM KVM cloud-init   ║"
echo -e "╚══════════════════════════════════════╝${NC}\n"

# -- Nom de la VM --------------------------------------------
while true; do
    read -rp "$(echo -e "${BOLD}Nom de la VM${NC} (ex: lit001) : ")" VM_NAME
    VM_NAME="${VM_NAME// /}"
    [[ -n "${VM_NAME}" ]] && break
    warn "Le nom ne peut pas être vide."
done

VM_DIR="${KVM_BASE}/${VM_NAME}"
[[ -d "${VM_DIR}" ]] && error "Le répertoire ${VM_DIR} existe déjà."

# -- Système d'exploitation ----------------------------------
echo ""
echo -e "  ${BOLD}OS disponibles :${NC}"
echo -e "  ${GREEN}1)${NC} Rocky Linux 9  (osinfo: rocky9)"
echo -e "  ${GREEN}2)${NC} Debian 13      (osinfo: debian13)"
echo ""
while true; do
    read -rp "$(echo -e "${BOLD}Choix OS${NC} [1/2] : ")" OS_CHOICE
    case "${OS_CHOICE}" in
        1) OS_TYPE="rocky9";   OS_LABEL="Rocky Linux 9"; IMAGE_FILE="${ROCKY_IMAGE}";  NET_IFACE="eth0";    break ;;
        2) OS_TYPE="debian13"; OS_LABEL="Debian 13";     IMAGE_FILE="${DEBIAN_IMAGE}"; NET_IFACE="enp1s0"; break ;;
        *) warn "Entrez 1 ou 2." ;;
    esac
done

[[ -f "${IMAGES_DIR}/${IMAGE_FILE}" ]] \
    || error "Image introuvable : ${IMAGES_DIR}/${IMAGE_FILE}"

# -- Réseau --------------------------------------------------
echo ""
while true; do
    read -rp "$(echo -e "${BOLD}Adresse IP${NC} (ex: 192.168.124.11) : ")" VM_IP
    [[ "${VM_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && break
    warn "Format IPv4 invalide."
done

while true; do
    read -rp "$(echo -e "${BOLD}Masque CIDR${NC} (ex: 24) : ")" VM_PREFIX
    [[ "${VM_PREFIX}" =~ ^[0-9]+$ ]] && (( VM_PREFIX >= 8 && VM_PREFIX <= 30 )) && break
    warn "Préfixe invalide (8-30)."
done

while true; do
    read -rp "$(echo -e "${BOLD}Gateway${NC}    (ex: 192.168.124.1) : ")" VM_GW
    [[ "${VM_GW}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && break
    warn "Format IPv4 invalide."
done

while true; do
    read -rp "$(echo -e "${BOLD}DNS${NC}        (ex: 10.255.255.254) : ")" VM_DNS
    [[ "${VM_DNS}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && break
    warn "Format IPv4 invalide."
done

# -- Domaine de recherche ------------------------------------
read -rp "$(echo -e "${BOLD}Search domain${NC} [kvm.local] : ")" VM_SEARCH
VM_SEARCH="${VM_SEARCH:-kvm.local}"

# -- Ressources ----------------------------------------------
echo ""
read -rp "$(echo -e "${BOLD}vCPUs${NC}  [2] : ")" VM_VCPUS
VM_VCPUS="${VM_VCPUS:-2}"

read -rp "$(echo -e "${BOLD}RAM (MiB)${NC} [2048] : ")" VM_MEM
VM_MEM="${VM_MEM:-2048}"

# -- Mot de passe --------------------------------------------
echo ""
read -rp "$(echo -e "${BOLD}Mot de passe root/cloud${NC} [abc123!] : ")" VM_PASS
VM_PASS="${VM_PASS:-abc123!}"

# ════════════════════════════════════════════════════════════
#  Résumé et confirmation
# ════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗"
echo -e "║                  Récapitulatif               ║"
echo -e "╚══════════════════════════════════════════════╝${NC}"
echo -e "  VM         : ${CYAN}${VM_NAME}${NC}"
echo -e "  OS         : ${CYAN}${OS_LABEL}${NC}  (osinfo: ${OS_TYPE})"
echo -e "  Image      : ${IMAGE_FILE}"
echo -e "  Répertoire : ${VM_DIR}"
echo -e "  IP         : ${VM_IP}/${VM_PREFIX}  gw=${VM_GW}  dns=${VM_DNS}  iface=${NET_IFACE}"
echo -e "  Search     : ${VM_SEARCH}"
echo -e "  vCPUs      : ${VM_VCPUS}   RAM: ${VM_MEM} MiB"
echo ""

read -rp "$(echo -e "${BOLD}Confirmer la création ? [o/N]${NC} : ")" CONFIRM
[[ "${CONFIRM,,}" =~ ^(o|oui|y|yes)$ ]] || { info "Annulé."; exit 0; }

# ════════════════════════════════════════════════════════════
#  Création de l'arborescence
# ════════════════════════════════════════════════════════════
info "Création du répertoire ${VM_DIR} …"
mkdir -p "${VM_DIR}"

# ── Copie de l'image ─────────────────────────────────────────
info "Copie de l'image ${IMAGE_FILE} …"
cp "${IMAGES_DIR}/${IMAGE_FILE}" "${VM_DIR}/${IMAGE_FILE}"
success "Image copiée."

# ════════════════════════════════════════════════════════════
#  meta-data
# ════════════════════════════════════════════════════════════
info "Génération de meta-data …"
cat > "${VM_DIR}/meta-data" <<EOF
instance-id: ${VM_NAME}
EOF
success "meta-data créé."

# ════════════════════════════════════════════════════════════
#  network-config
# ════════════════════════════════════════════════════════════
info "Génération de network-config …"
cat > "${VM_DIR}/network-config" <<EOF
version: 2
ethernets:
  ${NET_IFACE}:
    dhcp4: false
    addresses:
      - ${VM_IP}/${VM_PREFIX}
    gateway4: ${VM_GW}
    nameservers:
      search:
        - ${VM_SEARCH}
      addresses:
        - ${VM_DNS}
EOF
success "network-config créé."

# ════════════════════════════════════════════════════════════
#  user-data
# ════════════════════════════════════════════════════════════
info "Génération de user-data …"
cat > "${VM_DIR}/user-data" <<EOF
#cloud-config
---
ssh_authorized_keys:
  - ${SSH_PUBKEY}
hostname: ${VM_NAME}
fqdn: ${VM_NAME}.${VM_SEARCH}
prefer_fqdn_over_hostname: true
manage_etc_hosts: true
user: cloud
chpasswd:
  list: |
    root:${VM_PASS}
    cloud:${VM_PASS}
  expire: False
runcmd:
  - sleep 30
...
EOF
success "user-data créé."

# ════════════════════════════════════════════════════════════
#  virt-install.sh
# ════════════════════════════════════════════════════════════
info "Génération de virt-install.sh …"
cat > "${VM_DIR}/virt-install.sh" <<EOF
#!/usr/bin/env bash
# Auto-généré par create-vm.sh pour ${VM_NAME} (${OS_LABEL})

sudo virt-install \\
    --name ${VM_NAME} \\
    --osinfo ${OS_TYPE} \\
    --machine q35 \\
    --virt-type kvm \\
    --vcpus ${VM_VCPUS} \\
    --memory ${VM_MEM} \\
    --disk ${VM_DIR}/${IMAGE_FILE},device=disk,bus=virtio,format=qcow2 \\
    --cloud-init 'user-data=user-data,meta-data=meta-data,network-config=network-config' \\
    --network network=default \\
    --graphics vnc,listen=0.0.0.0,port=-1 \\
    --import
EOF
chmod +x "${VM_DIR}/virt-install.sh"
success "virt-install.sh créé."

# ════════════════════════════════════════════════════════════
#  Résultat final
# ════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}${BOLD}✔  VM ${VM_NAME} prête dans ${VM_DIR}${NC}"
echo ""
echo -e "  Fichiers générés :"
for f in meta-data network-config user-data virt-install.sh "${IMAGE_FILE}"; do
    echo -e "    ${CYAN}${VM_DIR}/${f}${NC}"
done
echo ""
echo -e "  Pour démarrer la VM :"
echo -e "    ${BOLD}cd ${VM_DIR} && bash virt-install.sh${NC}"
echo ""
