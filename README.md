# Projet - Cloud Computing

Application Flask minimaliste avec deux routes.

Endpoints :

Get / 🡢 La route d'accueil.

Get /services 🡢 La route de présentation des services.

## Structure du projet

### Arborescence

```text
cloud_computing/
├── README.md
├── .env
├── ansible/
│   ├── ansible.cfg
│   ├── deploy.sh
│   ├── inventory.ini
│   ├── playbook.yml
│   ├── vars.yml
│   └── group_vars/
│       └── api_server.yml
├── project/
│   ├── app.py
│   └── requirements.txt
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
└── rapport.pdf
```

### Rôle des répertoires

- `terraform/` : provisionnement de l'infrastructure Azure (VM, réseau, base SQL, outputs).
- `ansible/` : configuration de la VM, déploiement de l'API et automatisation avec playbook.
- `project/` : code source de l'application Flask et dépendances Python.

## Initialisation du projet

### Adapter les variables d'environnement

En tout premier lieu, il faut récupérer l'_.env.example_, le renommer en _.env_ et adapter les valeurs à l'environnement voulu.

```bash
cp .env.example .env
vim .env
```

Il faut obligatoirement modifier *MY_IP* et *SSH_KEY_PATH*.

**Pour récupérer son adresse ip :**

```bash
curl https://api.ipify.org
```

/!\ En cas de changement d'IP, une erreur 403 surviendra pendant le déploiement.

**Pour récupérer le chemin de la clé SSH :**

```bash
cd ~/.ssh/ && ll
```

/!\ Il faut impérativement utiliser une clé RSA, car la version azurerm utilisée est la 3.0, qui ne gère pas encore les clés ed25519.

Si besoin, vous pouvez générer une nouvelle clé SSH pour l'utiliser dans le cadre de ce projet.

```bash
ssh-keygen -t rsa -b 4096 -C "email@email.com" -f ~/.ssh/nom_de_la_clé
```

### S'authentifier auprès d'Azure

```bash
az login
```

Et suivre les instructions d'Azure.

### Mise en place de l'architecture et lancement du déploiement

Ensuite, toujours à la racine du projet, on peut directement lancer l'architecture et le déploiement avec la commande suivante.

```bash
./ansible/deploy.sh
```

Au bout de quelques minutes, l'API sera disponible à l'adresse indiquée dans le dernier output.
