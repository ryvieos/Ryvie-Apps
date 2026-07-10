# Ryvie App Store

**English** · [Français](README.fr.md)

> Part of the [Ryvie](https://github.com/ryvieos/Ryvie) ecosystem, the self-hosted personal cloud OS. Learn more at [ryvie.fr](https://ryvie.fr).

Ryvie-Apps is the one-click app catalog for Ryvie, a self-hosted personal cloud. Each application is a repository of Docker apps configured for Ryvie and ships a `docker-compose.yml`, a Ryvie configuration file (`ryvie-app.yml`) and its logo (`icon.png`).

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
```

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
