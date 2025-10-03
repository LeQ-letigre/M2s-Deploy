#!/bin/bash

set -e 

# === 1. Variables ===

INSTALL_TERRANSIBLE=$1
ID=$2
PASSWORD=$3
IP=$4
GATEWAY=$5
DNS=$6
BRIDGE=$7
INSTALL_WINSRV=$8
ID_WINSRV=$9
CONFS_URL=$10
LXC_TEMPLATE_FILENAME="debian-12-standard_12.7-1_amd64.tar.zst"
LXC_TEMPLATE="/var/lib/vz/template/cache/$LXC_TEMPLATE_FILENAME"
LXC_TEMPLATE_URL="http://download.proxmox.com/images/system/$LXC_TEMPLATE_FILENAME"
SSH_KEY_PATH="/root/.ssh/terransible"
node=$(hostname)
GITHUB_REPO=
SSH_KEY_PATH="/root/.ssh/terransible"
CONTAINER_SSH_PORT=22
PM_API=$(hostname -i)
TOKEN_USER="terraform-prov@pam"
TOKEN_NAME="auto-token"
USER_ROLE="Administrator"



if [ "$INSTALL_TERRANSIBLE" = "1" ]; then
    echo "[+] Vérification/installation de jq..."
    apt update && apt install -y jq
    if [ ! -f "$LXC_TEMPLATE" ]; then
    echo "[+] Téléchargement de l'image LXC $LXC_TEMPLATE_FILENAME..."
    wget -O "$LXC_TEMPLATE" "$LXC_TEMPLATE_URL"
    fi
    # === 2. Génération de la paire de clés SSH ===
    echo "[+] Génération de la paire de clés SSH pour le conteneur..."
    if [ ! -f "$SSH_KEY_PATH" ]; then
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
    fi

    PUB_KEY=$(cat "${SSH_KEY_PATH}.pub")

    echo "[+] Création du conteneur LXC "terransible"..."
    pct create $ID "$LXC_TEMPLATE" \
    -hostname terransible \
    -cores 4 \
    -memory 4096 \
    -net0 name=eth0,bridge=$BRIDGE,ip=$IP,gw=$GATEWAY \
    -storage local-lvm \
    -rootfs local-lvm:8 \
    -features nesting=1 \
    -password $PASSWORD \
    -unprivileged 0
    echo "[+] Démarrage du conteneur..."
    pct start $ID

    # === 4. Attente que le conteneur soit up ===
    echo "[+] Attente du démarrage du conteneur..."
    while ! ping -c 1 -W 1 "$IP" > /dev/null 2>&1; do
        sleep 1
    done

    # === 5. Injection de la clé SSH ===
    echo "[+] Injection de la clé SSH dans le conteneur..."
    pct exec $CTID -- mkdir -p /root/.ssh
    pct exec $CTID -- bash -c "echo '$PUB_KEY' > /root/.ssh/authorized_keys"
    pct exec $CTID -- chmod 600 /root/.ssh/authorized_keys

    # === 6. Authentification Proxmox et création du token ===
    echo "[+] Création du token Terraform sur Proxmox..."
    
    # === Création de l'utilisateur s'il n'existe pas ===
    if pveum user list | grep -q "$TOKEN_USER"; then
    echo "[!] L'utilisateur $TOKEN_USER existe déjà. Suppression en cours..."
    pveum user delete "$TOKEN_USER"
    fi
    echo "[+] Vérification/création de l'utilisateur $TOKEN_USER"
    pveum user list | grep -q "^$TOKEN_USER" || {
    pveum user add "$TOKEN_USER"
    echo "[+] Utilisateur $TOKEN_USER créé."
    }
    
    # === Attribution du rôle PVEAdmin sur / ===
    echo "[+] Attribution du rôle $USER_ROLE à $TOKEN_USER sur /"
    pveum acl modify / -user "$TOKEN_USER" -role "$USER_ROLE"
    
    # === Création du token ===
    echo "[+] Création du token $TOKEN_NAME..."
    TOKEN_OUTPUT=$(pveum user token add "$TOKEN_USER" "$TOKEN_NAME" --privsep 0 --output-format json 2>/dev/null)
    
    # === Vérification de la création ===
    if [ -z "$TOKEN_OUTPUT" ]; then
    echo "[!] Le token existe probablement déjà. Supprime-le avec :"
    echo "    pveum user token delete \"$TOKEN_USER\" \"$TOKEN_NAME\""
    exit 1
    fi
    
    # === Extraction du secret ===
    TF_TOKEN_ID="$TOKEN_USER!$TOKEN_NAME"
    TF_TOKEN_SECRET=$(echo "$TOKEN_OUTPUT" | jq -r '.value')
    
    # === Affichage final ===
    echo ""
    echo "Token créé avec succès :"
    echo "TF_TOKEN_ID     = $TF_TOKEN_ID"
    echo "TF_TOKEN_SECRET = $TF_TOKEN_SECRET"

    else
fi 

if [ "$INSTALL_WINSRV" = "1" ]; then
    echo "[+] Installation de Windows Server"
    # 1) Télécharger la backup du win srv 2022
    wget --no-check-certificate -O /var/lib/vz/dump/vzdump-qemu-101-2025_09_13-14_41_02.vma.zst https://m2shelper.boisloret.fr/scripts/deploy-terransible/vzdump-qemu-101-2025_09_13-14_41_02.vma.zst
    wget --no-check-certificate -O /var/lib/vz/dump/vzdump-qemu-101-2025_09_13-14_41_02.vma.zst.notes https://m2shelper.boisloret.fr/scripts/deploy-terransible/vzdump-qemu-101-2025_09_13-14_41_02.vma.zst.notes
    
    
    # 2) Restaurer sur le stockage voulu (ex: local-lvm) et VMID fixe (ex: 2000)
    qmrestore /var/lib/vz/dump/vzdump-qemu-101-2025_09_13-14_41_02.vma.zst  $ID_WINSRV --storage local-lvm --unique 1
    qm set $ID_WINSRV --name "WinTemplate"
    
    # 3) Marquer en template
    qm template $ID_WINSRV
else    
fi 
"
rm -f ~/.ssh/known_hosts

# Optionnel : attendre que la VM réponde au ping
echo "[+] Vérification que le conteneur est bien en ligne..."
until ping -c1 -W1 "$IP" >/dev/null 2>&1; do
  echo "⏳ En attente que $IP soit en ligne..."
  sleep 2
done

# === 7. SSH dans le conteneur pour la conf ===
ssh -T -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" root@"$IP" <<EOF

#!/bin/bash
set -e

# === Définition des variables dynamiques (remplies automatiquement dans ton script principal) ===
DISTRO="bookworm"
GITHUB_REPO="$GITHUB_REPO"
TOKEN_USER="$TOKEN_USER"
TOKEN_NAME="$TF_TOKEN_ID"
SECRET="$TF_TOKEN_SECRET"
node="$node"
lxc_template="$CHEMIN_TEMPLATE"
pm_api="$PM_API"
CONFS_URL="$CONFS_URL"

echo "🔧 Mise à jour des paquets..."
apt update && apt upgrade -y

echo "📦 Installation des outils de base..."
apt install -y sudo curl wget gnupg lsb-release software-properties-common unzip python3 python3-pip python3-venv git locales

echo "🌍 Correction des locales pour éviter les erreurs de type 'setlocale'..."
# Active en_US.UTF-8 dans le fichier des locales
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo "🐍 Création d’un venv global pour Ansible (Linux + Windows)..."
mkdir -p ~/venvs
python3 -m venv ~/venvs/ansible

echo "📦 Activation du venv et installation des dépendances Ansible + WinRM..."
source ~/venvs/ansible/bin/activate
pip install --upgrade pip
pip install ansible "pywinrm[credssp]" requests-ntlm

echo "🔗 Ajout d’un alias global dans ~/.bashrc pour ansible et ansible-playbook"
if ! grep -q "venvs/ansible" ~/.bashrc; then
  echo 'ansible() { source ~/venvs/ansible/bin/activate && command ansible "$@"; }' >> ~/.bashrc
  echo 'ansible-playbook() { source ~/venvs/ansible/bin/activate && command ansible-playbook "$@"; }' >> ~/.bashrc
fi

# Ajout du dépôt Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com bookworm main" \
  > /etc/apt/sources.list.d/hashicorp.list

apt update
apt install -y terraform


echo "[✔] Vérification de l'installation de Terraform..."
command -v terraform >/dev/null || { echo "❌ Terraform n’est pas installé correctement"; exit 1; }

echo "✅ VM terransible prête : Ansible, Terraform, Locales, Git et Alias configurés."

echo "[+] Clonage du dépôt Git..."
git clone "\$GITHUB_REPO" /Infra_GSB || { echo "❌ Clone Git échoué"; exit 1; }

echo "[+] Récupération du secrets.auto.tfvars..."
curl -k -o /Infra_GSB/Terraform/secrets.auto.tfvars "$CONFS_URL"

cd /Infra_GSB/Terraform
terraform init
terraform apply -auto-approve