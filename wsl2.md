# Laravel Development Environment — Ubuntu 26.04 LTS / WSL2

> **Scope:** Personal, isolated local development only. **Never deploy this configuration to production.**

## Status legend

GitHub renders the following native Markdown alerts with distinct colors and icons:

> [!NOTE]
> ℹ️ **INFO** — Background information or expected behavior.

> [!TIP]
> 💡 **TIP** — Optional improvements.

> [!IMPORTANT]
> ✅ **REQUIRED** — A prerequisite or action that must succeed.

> [!WARNING]
> ⚠️ **WARNING** — A likely configuration problem or compatibility risk.

> [!CAUTION]
> 🛑 **CAUTION** — An unsafe action, destructive operation, or security exposure.

> [!IMPORTANT]
> ❌ **ERROR** — If a command prints `ERROR`, stop and resolve it; do not continue with a partially installed stack. GitHub has no dedicated `[!ERROR]` alert type, so errors use an IMPORTANT alert and the ❌ icon.

## Stack and update policy

| Component                   | Target                    | Update behavior                                                      |
| --------------------------- | ------------------------- | -------------------------------------------------------------------- |
| Ubuntu                      | 26.04 LTS, native or WSL2 | Ubuntu package updates                                               |
| PHP                         | 8.5 CLI + FPM             | Latest **8.5.x** available in configured APT repositories            |
| MySQL                       | 8.4 LTS                   | Latest **8.4.x** available; version checked before and after install |
| Apache                      | Ubuntu-supported 2.4.x    | Ubuntu security/maintenance updates                                  |
| phpMyAdmin                  | Ubuntu package            | Ubuntu repository updates                                            |
| Composer                    | Latest stable             | `composer self-update --stable`                                      |
| Laravel installer           | Latest compatible stable  | `composer global update laravel/installer`                           |
| Node.js                     | Latest **24.x** LTS       | `nvm install 24 --latest-npm`                                        |
| Bun                         | Latest stable             | `bun upgrade`                                                        |
| Git, GitHub CLI, GitLab CLI | Ubuntu packages           | Ubuntu repository updates                                            |

> [!WARNING]
> **Latest does not mean latest major.** This guide intentionally stays on PHP 8.5, MySQL 8.4, and Node.js 24. Future major releases may break compatibility. APT upgrades do not automatically move to a new Ubuntu release, nor do they guarantee a particular upstream version. The updater below refreshes supported versions **when you run it**; it is not an unattended background updater.

**Requirements:** Ubuntu 26.04 LTS, `sudo` privileges, internet access, and sufficient free disk space (allow 10 GB or more). The guide assumes Bash and a fresh or otherwise compatible installation.

## 1. WSL2 installation (Windows only)

Run in **Administrator PowerShell**:

```powershell
wsl --update
wsl --list --online
wsl --install -d Ubuntu-26.04
```

> [!WARNING]
> The distro name must appear in `wsl --list --online`. If it does not, stop; do not substitute a different release without reviewing package compatibility.

In Ubuntu, check systemd:

```bash
ps -p 1 -o comm=
```

If it is not `systemd`, enable it:

```bash
sudo install -d /etc
printf '[boot]\nsystemd=true\n' | sudo tee /etc/wsl.conf >/dev/null
```

Then run `wsl --shutdown` in PowerShell and reopen Ubuntu.

> [!TIP]
> Keep projects in `~/projects` inside the Linux filesystem, not under `/mnt/c`, for better filesystem performance.

## 2. One-time core installation (single Bash block)

Copy and paste the **entire block** into Ubuntu. It installs system packages, PHP, MySQL, Apache, phpMyAdmin, Composer, the Laravel installer, Git CLIs, Node.js, and Bun. It also configures PHP, Bash history, and `cls`. No name, email, or path edits are required.

> [!CAUTION]
> This block configures **passwordless MySQL root access and phpMyAdmin root auto-login**. Anyone who can reach the database or phpMyAdmin can obtain full database control. Only use it on an isolated, personally controlled machine. The script restricts Apache's default listener and MySQL's TCP bind address to loopback, but review WSL port forwarding, tunnels, proxies, firewall rules, and any additional virtual hosts yourself.

> [!WARNING]
> A fresh Ubuntu 26.04 installation is recommended. The script stops if the package candidate is not PHP 8.5 / MySQL 8.4 or if the installed MySQL version differs. It does **not** add third-party repositories or silently upgrade to incompatible major versions.

```bash
bash <<'SETUP'
set -Eeuo pipefail
trap 'echo "ERROR: Setup failed at line $LINENO. Review the output above." >&2' ERR

if [ "$(id -u)" -eq 0 ]; then
  echo 'ERROR: Run as your regular Ubuntu user, not root.' >&2
  exit 1
fi

. /etc/os-release
if [ "${ID:-}" != ubuntu ] || [ "${VERSION_ID:-}" != 26.04 ]; then
  echo 'ERROR: Ubuntu 26.04 is required.' >&2
  exit 1
fi

sudo -v
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get full-upgrade -y
sudo apt-get install -y \
  ca-certificates curl wget gnupg git unzip zip zstd \
  build-essential tree htop acl python3 \
  php8.5-cli php8.5-fpm php8.5-bcmath php8.5-curl \
  php8.5-gd php8.5-intl php8.5-mbstring php8.5-mysql \
  php8.5-xml php8.5-zip php8.5-sqlite3 \
  mysql-server mysql-client apache2 gh glab

PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
[ "$PHP_VERSION" = '8.5' ] || { echo 'ERROR: PHP 8.5 is required.' >&2; exit 1; }

MYSQL_VERSION="$(sudo mysql -Nse 'SELECT VERSION()' | cut -d. -f1,2)"
[ "$MYSQL_VERSION" = '8.4' ] || { echo 'ERROR: MySQL 8.4 is required.' >&2; exit 1; }

sudo tee /etc/php/8.5/mods-available/local-dev.ini >/dev/null <<'PHP_INI'
memory_limit = 1024M
max_execution_time = 300
max_input_time = 300
upload_max_filesize = 512M
post_max_size = 520M
max_input_vars = 5000
max_file_uploads = 100
date.timezone = Asia/Dhaka
display_errors = On
display_startup_errors = On
log_errors = On
error_reporting = E_ALL
realpath_cache_size = 32M
realpath_cache_ttl = 120
opcache.enable = 1
opcache.enable_cli = 0
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 32
opcache.max_accelerated_files = 50000
opcache.validate_timestamps = 1
opcache.revalidate_freq = 0
opcache.save_comments = 1
PHP_INI
sudo phpenmod -v 8.5 -s cli local-dev
sudo phpenmod -v 8.5 -s fpm local-dev

# Keep MySQL TCP access local and avoid deprecated mysql_native_password.
sudo tee /etc/mysql/mysql.conf.d/99-local-dev.cnf >/dev/null <<'MYSQL_CNF'
[mysqld]
bind-address=127.0.0.1
MYSQL_CNF
sudo systemctl enable --now mysql php8.5-fpm apache2
sudo systemctl restart mysql php8.5-fpm

# Empty-password root login is intentionally limited to this local-only setup.
sudo mysql <<'MYSQL_SQL'
ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '';
MYSQL_SQL
mysql -h 127.0.0.1 -u root -Nse 'SELECT CURRENT_USER(), VERSION();'

# Configure Apache's main listener for local access only.
if grep -Eq '^Listen 80$' /etc/apache2/ports.conf; then
  sudo sed -i 's/^Listen 80$/Listen 127.0.0.1:80/' /etc/apache2/ports.conf
fi
sudo a2enmod rewrite proxy_fcgi setenvif headers
sudo a2enconf php8.5-fpm

# Preselect Apache for the Ubuntu phpMyAdmin package.
printf 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2\n' \
  | sudo debconf-set-selections
sudo apt-get install -y phpmyadmin
if [ -f /etc/apache2/conf-available/phpmyadmin.conf ]; then
  sudo a2enconf phpmyadmin
elif [ -f /etc/phpmyadmin/apache.conf ]; then
  sudo ln -sfn /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
  sudo a2enconf phpmyadmin
else
  echo 'ERROR: phpMyAdmin Apache configuration not found.' >&2
  exit 1
fi

# Debian/Ubuntu phpMyAdmin loads conf.d/*.php when included by its package config.
if ! grep -q 'conf.d' /etc/phpmyadmin/config.inc.php; then
  echo 'ERROR: Confirm phpMyAdmin loads /etc/phpmyadmin/conf.d before enabling auto-login.' >&2
  exit 1
fi
sudo install -d -m 755 /etc/phpmyadmin/conf.d
sudo tee /etc/phpmyadmin/conf.d/99-local-autologin.php >/dev/null <<'PMA_PHP'
<?php
$cfg['Servers'][1]['auth_type'] = 'config';
$cfg['Servers'][1]['user'] = 'root';
$cfg['Servers'][1]['password'] = '';
$cfg['Servers'][1]['AllowNoPassword'] = true;
PMA_PHP
sudo apache2ctl configtest
sudo systemctl restart apache2

# Verify Composer's current installer signature before execution.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
curl -fsSL https://getcomposer.org/installer -o "$TMP_DIR/composer-setup.php"
EXPECTED="$(curl -fsSL https://composer.github.io/installer.sig)"
ACTUAL="$(php -r 'echo hash_file("sha384", $argv[1]);' "$TMP_DIR/composer-setup.php")"
[ "$EXPECTED" = "$ACTUAL" ] || { echo 'ERROR: Composer signature mismatch.' >&2; exit 1; }
php "$TMP_DIR/composer-setup.php" --install-dir="$TMP_DIR" --filename=composer
sudo install -m 755 "$TMP_DIR/composer" /usr/local/bin/composer
composer global require laravel/installer

# Resolve the current stable nvm release instead of hardcoding an installer tag.
NVM_TAG="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')"
curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_TAG}/install.sh" -o "$TMP_DIR/nvm-install.sh"
bash "$TMP_DIR/nvm-install.sh"
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
nvm install 24 --latest-npm
nvm alias default 24

curl -fsSL https://bun.sh/install -o "$TMP_DIR/bun-install.sh"
bash "$TMP_DIR/bun-install.sh"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$(composer global config bin-dir --absolute):$PATH"

# Keep this managed Bash section idempotent.
if ! grep -Fq '# >>> Laravel local development >>>' "$HOME/.bashrc"; then
  cat >> "$HOME/.bashrc" <<'BASH_CONFIG'

# >>> Laravel local development >>>
export HISTFILE=~/.bash_history
export HISTSIZE=10000
export HISTFILESIZE=0
alias cls='clear'
export PATH="$HOME/.config/composer/vendor/bin:$HOME/.bun/bin:$PATH"
# <<< Laravel local development <<<
BASH_CONFIG
fi

mkdir -p "$HOME/projects"
printf '\nSUCCESS: Core installation finished. Open a new Ubuntu terminal.\n'
printf 'phpMyAdmin: http://localhost/phpmyadmin\n'
SETUP
```

> [!IMPORTANT]
> **Post-install:** Open a **new Ubuntu terminal** to load the NVM/Bun/Composer PATH changes. Do not run the entire installer repeatedly to update packages; use the maintenance command in Section 4 instead.

> [!WARNING]
> The phpMyAdmin package may change how it includes `conf.d` or initializes its server configuration. Verify that `http://localhost/phpmyadmin` actually logs in as root; never assume the override works solely because the file was created. The script intentionally stops if it cannot detect the include directory.

## 3. Interactive Git identity and authentication

Run this block once. It prompts for your name and email **at runtime**, so you never need to edit commands before pasting:

```bash
bash <<'GIT_SETUP'
set -Eeuo pipefail
read -r -p 'Git display name: ' GIT_NAME
read -r -p 'Git email address: ' GIT_EMAIL
[ -n "$GIT_NAME" ] && [[ "$GIT_EMAIL" == *@* ]] || {
  echo 'ERROR: Enter a non-empty name and a valid-looking email.' >&2
  exit 1
}
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
printf '\nConfigured Git identity:\n'
git config --global --get user.name
git config --global --get user.email

read -r -p 'Authenticate GitHub CLI now? [y/N]: ' ANSWER
if [[ "$ANSWER" =~ ^[Yy]$ ]]; then gh auth login; fi
read -r -p 'Authenticate GitLab CLI now? [y/N]: ' ANSWER
if [[ "$ANSWER" =~ ^[Yy]$ ]]; then glab auth login; fi
GIT_SETUP
```

Optional interactive SSH key setup:

```bash
read -r -p 'SSH key comment (email): ' SSH_EMAIL
ssh-keygen -t ed25519 -C "$SSH_EMAIL"
cat "$HOME/.ssh/id_ed25519.pub"
```

Add the public key to your provider account, then test with `ssh -T git@github.com` or `ssh -T git@gitlab.com`.

## 4. One-command maintenance (latest compatible releases)

Create a reusable update command once:

```bash
sudo tee /usr/local/bin/laravel-dev-update >/dev/null <<'UPDATE_SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "ERROR: Update failed at line $LINENO." >&2' ERR
if [ "$(id -u)" -eq 0 ]; then
  echo 'ERROR: Run as a normal user, not root.' >&2
  exit 1
fi
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get autoremove -y
composer self-update --stable
composer global update laravel/installer
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
nvm install 24 --latest-npm
nvm alias default 24
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
bun upgrade
printf '\nSUCCESS: Available compatible updates installed.\n'
UPDATE_SCRIPT
sudo chmod 755 /usr/local/bin/laravel-dev-update
```

Later, update the environment with **one command**:

```bash
laravel-dev-update
```

> [!WARNING]
> `apt upgrade` uses your **configured** Ubuntu repositories and does not guarantee new upstream major releases. `composer global update` obeys dependency constraints. `nvm install 24` stays on Node 24. `bun upgrade` may introduce a new Bun major version; check release notes before using it on critical projects. Existing Laravel project dependencies are **not** updated automatically: update them per project after reviewing changes.

> [!CAUTION]
> Do not schedule unattended major-version upgrades on this passwordless-root development environment. Review updates and back up databases before significant changes.

## 5. Shell history and `cls`

The installer already adds these settings once to `~/.bashrc`:

```bash
export HISTFILE=~/.bash_history
export HISTSIZE=10000
export HISTFILESIZE=0
alias cls='clear'
```

`HISTFILESIZE=0` disables Bash's history-file truncation limit; `HISTSIZE=10000` retains 10,000 commands in the in-memory list. Open a new shell or run `source ~/.bashrc` to activate the alias in an existing interactive shell. Run `cls` to clear the terminal.

## 6. MySQL root and Laravel configuration

The installer uses MySQL's `caching_sha2_password` plugin, not the removed/deprecated `mysql_native_password` approach. It intentionally sets an **empty root password**.

Check root login and create a project database:

```bash
mysql -h 127.0.0.1 -u root -e 'CREATE DATABASE IF NOT EXISTS laravel_dev CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
```

Example project `.env`:

```dotenv
APP_ENV=local
APP_DEBUG=true
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel_dev
DB_USERNAME=root
DB_PASSWORD=
```

> [!CAUTION]
> Empty-password MySQL root is a conscious security compromise. If your MySQL build, authentication policy, or client rejects it, **stop and inspect the exact error**; do not enable obsolete plugins or disable security controls indiscriminately. A root account without a password is not suitable for shared machines or network access.

## 7. Final verification (single block)

```bash
bash <<'VERIFY'
set -Eeuo pipefail
printf '\n=== Versions ===\n'
php -v | head -n 1
composer --version
laravel --version
mysql -h 127.0.0.1 -u root -Nse 'SELECT VERSION();'
apache2 -v | head -n 1
node -v
npm -v
bun -v
git --version
gh --version | head -n 1
glab --version | head -n 1
printf '\n=== Services ===\n'
for service in mysql apache2 php8.5-fpm; do
  printf '%s: ' "$service"
  systemctl is-active --quiet "$service" && echo active || { echo inactive; exit 1; }
done
printf '\n=== Connectivity ===\n'
curl -fsSI http://127.0.0.1/ | head -n 1
curl -fsSI http://127.0.0.1/phpmyadmin/ | head -n 1
printf '\nSUCCESS: Basic service checks passed.\n'
VERIFY
```

> [!NOTE]
> HTTP status and CLI checks cannot prove phpMyAdmin authentication or a Laravel application works end-to-end. Confirm root auto-login in your browser and test database access in an actual project.

## 8. Troubleshooting

| Symptom                                  | Action                                                                                                                |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| ❌ `php8.5-*` package not found          | Confirm Ubuntu release, run `apt-cache policy php8.5-cli`, inspect enabled repositories.                              |
| ❌ MySQL version is not 8.4              | Check `sudo mysql -Nse 'SELECT VERSION();'` and APT package sources; stop instead of forcing an incompatible upgrade. |
| ❌ Empty-password root login fails       | Inspect MySQL error output and authentication policy; do not fall back to `mysql_native_password`.                    |
| ⚠️ `systemctl` fails in WSL              | Enable systemd, run `wsl --shutdown` from Windows, reopen Ubuntu.                                                     |
| ⚠️ `node`, `bun`, or `laravel` not found | Open a new Ubuntu terminal; check shell initialization and PATH.                                                      |
| ⚠️ phpMyAdmin does not auto-login        | Verify `/etc/phpmyadmin/config.inc.php` loads `conf.d`, the server index, and browser access.                         |
| ⚠️ Apache unavailable from Windows       | Check WSL localhost forwarding and that Apache listens on `127.0.0.1:80`.                                             |
| ℹ️ `cls` not found                       | Open a new Bash shell or run `source ~/.bashrc`.                                                                      |

## Official documentation

- [Ubuntu](https://documentation.ubuntu.com/)
- [WSL](https://learn.microsoft.com/windows/wsl/)
- [PHP](https://www.php.net/manual/en/)
- [Composer](https://getcomposer.org/download/)
- [Laravel](https://laravel.com/docs)
- [MySQL 8.4](https://dev.mysql.com/doc/refman/8.4/en/)
- [Apache](https://httpd.apache.org/docs/2.4/)
- [phpMyAdmin](https://docs.phpmyadmin.net/)
- [nvm](https://github.com/nvm-sh/nvm)
- [Bun](https://bun.sh/docs)

---

**No project scaffolding or Apache virtual-host automation is included.** This document intentionally covers environment installation, interactive Git configuration, maintenance, and verification only.
