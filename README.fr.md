# Ryvie App Store

[English](README.md) · **Français**

> Fait partie de l'écosystème [Ryvie](https://github.com/ryvieos/Ryvie), l'OS de cloud personnel auto-hébergé. Plus d'infos sur [ryvie.fr](https://ryvie.fr).

Ryvie-Apps est le catalogue d'applications en un clic de Ryvie, un cloud personnel auto-hébergé. C'est un dépôt d'applications Docker configurées pour Ryvie. Chaque application est livrée avec un fichier `docker-compose.yml` et sa configuration Ryvie (`ryvie-app.yml`) ainsi que son logo (`icon.png`).

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
```

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
- [ ] Respecte les bonnes pratiques Docker (ne pas utiliser d'image "latest" par exemple)

---

## 📞 Questions ?

Ouvrez une "issue" ou contactez les mainteneurs du projet.
