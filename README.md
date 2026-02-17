# Ryvie App Store

Contribution tutorial :

---
ENGLISH VERSION (french below)
---

# Ryvie-Apps

Ryvie-Apps is a repository of Docker applications configured for Ryvie. Each application includes a `docker-compose.yml`, a Ryvie configuration file (`ryvie-app.yml`) and its logo (`icon.png`).

---

## 📋 How to propose a new application or a change

We welcome contributions! Follow this guide to propose new applications or improvements. 

### Contribution steps

#### 1. **Create a branch from `dev`**
```bash
git checkout dev
git pull origin dev
git checkout -b feature/your-app-name
```
Use a clear branch name:
- `feature/new-app` for a new application
- `fix/existing-app-bug` for a bug fix

#### 2. **Prepare your contribution**

- **New application**: Create a folder with:
  - `docker-compose.yml`: Full Docker configuration
  - `ryvie-app.yml`: Ryvie metadata (name, description, version, etc.)
  - `icon.png`: Application logo
  - `install.sh`: Installation script if needed
  - Any additional configuration files

#### `ryvie-app.yml` configuration
```yaml
manifestVersion: 1
id: rdrive
category: 
  fr: Storage
  en: Storage
name: rDrive
version: "1.0.0"
buildId: 1
port: 3010
description: 
  fr: "Long French description of your application. You can detail the main features, use cases, etc."
  en: "Long English description of your application. You can detail the main features, use cases, etc."
tagline: 
  fr: "Short French tagline"
  en: "Short English tagline"
gallery:
  - icon.png
  - image1.png
  - image2.png
```

**Key fields:**
- `manifestVersion`: number
- `id`: Unique identifier (lowercase, hyphens)
- `category`: Category in French and English
- `name`: Display name
- `buildId`: initialize to 0; it will be incremented automatically
- `version`: Semantic version
- `port`: Main access port
- `description`: Long descriptions in fr/en
- `tagline`: Short descriptions in fr/en
- `gallery`: Images to display (`icon.png` required)

- **Existing modification**: Edit the relevant files in the application's folder

#### 3. **Create a clear Pull Request**

Go to GitHub and create a PR with these elements:

**PR title** (required):
```
feature: Add rDrive application
fix: Fix Jellyfin port
```

Start with:
- `feature:` for a new application
- `fix:` for a bug fix
- `docs:` for documentation updates

**PR description** (required):

```markdown
## Description
[Briefly explain what you are adding or fixing]

## Added items
- [Item 1]
- [Item 2]
- [Item 3]

## Benefits to the project
- [Benefit 1]
- [Benefit 2]

## How to use / install
1. [Step 1]
2. [Step 2]
3. [Step 3]

## Ports used
- Port X: [service]
- Port Y: [service]

## Required environment variables
```bash
VARIABLE_1=value
VARIABLE_2=value
```

## Test the contribution
- [ ] `docker-compose.yml` works correctly
- [ ] The application starts without errors
- [ ] `ryvie-app.yml` is valid
```

### Concrete example

**Title**: `feature: Add rDrive application`

**Description**:
```
## Description
Add rDrive, a self-hosted file storage solution: secure and easy to use.

## Added items
- rDrive service with file sync support
- Docker configuration optimized for Ryvie
- `icon.png` and gallery images
- Installation script to initialize storage volumes

## Benefits to the project
- Complete, self-contained storage solution for Ryvie
- Intuitive file management UI
- Easy sync and sharing between Ryvie services
- Local hosting, no external cloud required

## How to use
Once installed via the Ryvie AppStore:
1. Open rDrive from the Ryvie dashboard
2. Create folders and organize your files
3. Sync data with other Ryvie services
4. Share files with other users

## Ports used
- Port 3010: rDrive web interface

## Test
- [x] `docker-compose.yml` works correctly
- [x] The application starts without errors
- [x] `ryvie-app.yml` is valid and contains descriptions in fr/en
- [x] Gallery images are present and optimized

---

## 📝 Checklist before submitting

Make sure your contribution:

- [ ] Uses a branch created from `dev`
- [ ] Respects the structure of other applications
- [ ] Contains essential files (`docker-compose.yml`, `ryvie-app.yml`, and `icon.png`)
- [ ] Has a PR with a title starting with `feature:` or `fix:`
- [ ] Includes a complete and detailed description
- [ ] Has been tested locally
- [ ] Does not contain temporary or sensitive files
- [ ] Follows Docker best practices (do not use `latest` image tags)

---

## 📞 Questions?

Open an "issue" or contact the project maintainers.


---
VERSION FRANCAISE
---

# Ryvie-Apps

Ryvie-Apps est un dépôt d'applications Docker configurées pour Ryvie. Chaque application est livrée avec un fichier `docker-compose.yml` et sa configuration Ryvie (`ryvie-app.yml`) ainsi que son logo (`icon.png`).

---

## 📋 Comment proposer une nouvelle application ou une modification

Nous accueillons les contributions ! Suivez ce guide pour proposer de nouvelles applications ou des améliorations.

### Étapes de contribution

#### 1. **Créer une branche depuis `dev`**
```bash
git checkout dev
git pull origin dev
git checkout -b feature/nom-de-votre-app
```
Utilisez un nom de branche explicite :
- `feature/nouvelle-app` pour une nouvelle application
- `fix/bug-app-existante` pour une correction

#### 2. **Préparer votre contribution**

- **Nouvelle application** : Créez un dossier avec :
  - `docker-compose.yml` : Configuration Docker complète
  - `ryvie-app.yml` : Métadonnées Ryvie (nom, description, version, etc.)
  - `icon.png` : Logo de l'application
  - `install.sh` : Script d'installation si nécessaire
  - Tout fichier de configuration supplémentaire

#### Configuration du `ryvie-app.yml`
```yaml
manifestVersion: 1
id: rdrive
category: 
  fr: Stockage
  en: Storage
name: rDrive
version: "1.0.0"
buildId: 1
port: 3010
description: 
  fr: "Description longue en français de votre application. Vous pouvez détailler les fonctionnalités principales, les cas d'usage, etc."
  en: "Long English description of your application. You can detail the main features, use cases, etc."
tagline: 
  fr: "Tagline court en français"
  en: "Short English tagline"
gallery:
  - icon.png
  - image1.png
  - image2.png
```

**Paramètres clés :**
- `manifestVersion` : chiffre
- `id` : Identifiant unique (minuscules, tirets)
- `category` : Catégorie en français et anglais
- `name` : Nom affiché
- `buildId` : l'initialisé à 0, il sera incrémenté automatiquement
- `version` : Version sémantique
- `port` : Port principal d'accès
- `description` : Descriptions longues en fr/en
- `tagline` : Courte description en fr/en
- `gallery` : Images à afficher (icon.png obligatoire)

- **Modification existante** : Modifiez les fichiers pertinents dans le dossier de l'application

#### 3. **Créer une Pull Request claire**

Allez sur GitHub et créez une PR avec ces éléments :

**Titre de la PR** (obligatoire) :
```
feature: Ajouter l'application Nextcloud
fix: Corriger le port de Jellyfin
```

Commencez par :
- `feature:` pour une nouvelle application
- `fix:` pour une correction de bug
- `docs:` pour une mise à jour de documentation

**Description de la PR** (obligatoire) :

```markdown
## Description
[Explique brièvement ce que tu ajoutes ou ce que tu corriges]

## Éléments ajoutés
- [Élément 1]
- [Élément 2]
- [Élément 3]

## Bénéfices pour le projet
- [Bénéfice 1]
- [Bénéfice 2]



## Ports utilisés
- Port X: [service]
- Port Y: [service]

## Variables d'environnement nécessaires
```bash
VARIABLE_1=valeur
VARIABLE_2=valeur
```

## Tester la contribution
- [ ] Le docker-compose.yml fonctionne correctement
- [ ] L'application démarre sans erreur
- [ ] Le fichier ryvie-app.yml est valide
```

### Exemple concret

**Titre** : `feature: Ajouter l'application rDrive`

**Description** :
```
## Description
Ajout de rDrive, une solution de stockage de fichiers auto-hébergée, sécurisée et facile à utiliser.

## Éléments ajoutés
- Service rDrive avec support de synchronisation des fichiers
- Configuration Docker optimisée pour Ryvie
- Fichiers icon.png et images pour la galerie
- Script d'installation pour initialiser les volumes de stockage

## Bénéfices pour le projet
- Solution de stockage complète et autonome pour Ryvie
- Interface intuitive pour gérer les fichiers
- Synchronisation et partage faciles entre les services Ryvie
- Données hébergées localement, pas de cloud externe

## Comment l'utiliser
Une fois installée via l'AppStore Ryvie :
1. Accéder à rDrive depuis le dashboard
2. Créer des dossiers et organiser vos fichiers
3. Synchroniser les données sur d'autres services Ryvie
4. Partager les fichiers avec d'autres utilisateurs

## Ports utilisés
- Port 3010: Interface web rDrive

## Tester
- [x] Le docker-compose.yml fonctionne correctement
- [x] L'application démarre sans erreur
- [x] Le fichier ryvie-app.yml est valide et contient les descriptions en fr/en
- [x] Les images de la galerie sont présentes et optimisées

---

## 📝 Checklist avant de proposer

Assurez-vous que votre contribution :

- [ ] Utilise une branche créée depuis `dev`
- [ ] Respecte la structure des autres applications
- [ ] Contient les fichiers essentiels (`docker-compose.yml`, `ryvie-app.yml` et icon.png)
- [ ] Dispose d'une PR avec titre commençant par `feature:` ou `fix:`
- [ ] Inclut une description complète et détaillée
- [ ] A été testée localement
- [ ] Ne contient pas de fichiers temporaires ou sensibles
- [ ] Respecte les bonnes pratiques Docker (ne pas utilisé d'image "latest" par exemple)

---

## 📞 Questions ?

Ouvrez une "issue" ou contactez les mainteneurs du projet.
