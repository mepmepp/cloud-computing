#!/bin/bash
set -e

# 1. Charger le .env
if [ ! -f .env ]; then
  echo "Fichier .env manquant. Copiez .env.example, renommez le en .env et remplissez les valeurs."
  exit 1
fi

set -a
source .env
set +a

# 2. Vérifier que les variables obligatoires sont bien remplies
required_vars=("MY_IP" "PREFIX" "COMPUTER_NAME" "ADMIN_USERNAME" "ADMIN_PASSWORD" "SSH_KEY_PATH" "APP_PORT" "DB_NAME" "DB_USER" "DB_PASSWORD")
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "Variable $var manquante dans .env"
    exit 1
  fi
done

# 3. Créer les TF_VAR_ pour Terraform
export TF_VAR_my_ip_address=$MY_IP
export TF_VAR_prefix=$PREFIX
export TF_VAR_computer_name=$COMPUTER_NAME
export TF_VAR_admin_username=$ADMIN_USERNAME
export TF_VAR_admin_password=$ADMIN_PASSWORD
export TF_VAR_local_ssh_key_path=$SSH_KEY_PATH
export TF_VAR_app_port=$APP_PORT
export TF_VAR_db_name=$DB_NAME
export TF_VAR_db_user=$DB_USER
export TF_VAR_db_password=$DB_PASSWORD

# 4. Terraform crée la VM avec ces valeurs
cd terraform
terraform init -input=false
terraform apply -auto-approve
terraform output ip_publique

# 5. Récupérer l'IP et le FQDN et lancer Ansible
export IP_PUBLIQUE=$(terraform output -raw ip_publique)
export DB_SERVER=$(terraform output -raw db_server)

cd ../ansible
ansible-playbook -i inventory.ini playbook.yml -v

echo "API accessible sur : http://${IP_PUBLIQUE}:${APP_PORT}"
