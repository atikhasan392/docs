# Laravel Development Environment Setup

## Ubuntu 26.04 LTS / WSL2 - Complete Guide

> [!WARNING]
> **This setup is designed strictly for local development on Ubuntu 26.04 LTS or WSL2**
>
> **⚠️ Do not use this configuration on production servers.**
>
> This guide intentionally enables developer-friendly settings:
>
> - Verbose PHP error reporting
> - Passwordless local MySQL root access
> - Automatic phpMyAdmin login
>
> These settings are convenient for development but **unsafe in production**.

---

## Stack Overview

| Component             | Version             | Purpose                                      |
| --------------------- | ------------------- | -------------------------------------------- |
| **WSL 2**             | Latest stable       | Linux virtualization for Windows development |
| **Ubuntu**            | 26.04 LTS           | Linux development environment                |
| **PHP**               | 8.5 NTS (FPM + CLI) | Laravel backend runtime                      |
| **Composer**          | Latest stable       | PHP dependency manager                       |
| **Laravel Installer** | Latest stable       | Project scaffolding                          |
| **MySQL**             | 8.4 LTS             | Relational database                          |
| **Apache**            | 2.x                 | Local web server with PHP-FPM                |
| **phpMyAdmin**        | Latest stable       | Database administration UI                   |
| **Node.js**           | 24 LTS              | Frontend build tooling                       |
| **Bun**               | Latest stable       | JavaScript runtime & package manager         |
| **Git**               | Latest stable       | Version control                              |
| **GitHub CLI**        | Latest stable       | GitHub workflow automation                   |

---

## Prerequisites

- ✓ Fresh Ubuntu 26.04 LTS or WSL2 Ubuntu installation
- ✓ Administrator/sudo privileges available
- ✓ Command line familiarity
- ✓ Approximately 10GB disk space
- ✓ Replace all placeholder values before running commands

---

## WSL 2 Installation

```powershell
wsl --install
wsl --list --online
wsl --install -d Ubuntu-26.04

# ⚠️ WARNING: This permanently deletes the WSL distribution and all its files
# wsl --unregister Ubuntu-26.04
```

---

## System Setup

```bash
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y

sudo apt install -y \
  curl wget gnupg ca-certificates lsb-release \
  apt-transport-https software-properties-common \
  zip unzip git build-essential
```

---

## PHP 8.5 Installation

```bash
sudo apt update

sudo apt install -y \
  php8.5 php8.5-fpm php8.5-cli \
  php8.5-common \
  php8.5-bcmath php8.5-curl php8.5-xml php8.5-gd \
  php8.5-mbstring php8.5-mysql php8.5-zip \
  php8.5-intl php8.5-readline \
  php8.5-redis php8.5-msgpack php8.5-igbinary \
  php8.5-sqlite3 php8.5-pgsql

# Verify installation
php -v
php -m | grep -E "Zend OPcache|bcmath|curl|gd|intl|mbstring|mysqli|mysqlnd|pdo_mysql|redis|zip"

# Enable and start PHP-FPM
sudo systemctl enable --now php8.5-fpm
systemctl status php8.5-fpm --no-pager

# Configure PHP for Local Development
PHP_VERSION="8.5"

for PHP_INI in /etc/php/${PHP_VERSION}/cli/php.ini /etc/php/${PHP_VERSION}/fpm/php.ini; do
  [ -f "$PHP_INI" ] || continue

  sudo cp "$PHP_INI" "$PHP_INI.bak.$(date +%F-%H%M%S)"

  sudo sed -i \
    -e 's|^;*[[:space:]]*memory_limit[[:space:]]*=.*|memory_limit = 1024M|' \
    -e 's|^;*[[:space:]]*max_execution_time[[:space:]]*=.*|max_execution_time = 300|' \
    -e 's|^;*[[:space:]]*max_input_time[[:space:]]*=.*|max_input_time = 300|' \
    -e 's|^;*[[:space:]]*upload_max_filesize[[:space:]]*=.*|upload_max_filesize = 5120M|' \
    -e 's|^;*[[:space:]]*post_max_size[[:space:]]*=.*|post_max_size = 5120M|' \
    -e 's|^;*[[:space:]]*max_input_vars[[:space:]]*=.*|max_input_vars = 5000|' \
    -e 's|^;*[[:space:]]*date\.timezone[[:space:]]*=.*|date.timezone = Asia/Dhaka|' \
    -e 's|^;*[[:space:]]*display_errors[[:space:]]*=.*|display_errors = On|' \
    -e 's|^;*[[:space:]]*display_startup_errors[[:space:]]*=.*|display_startup_errors = On|' \
    -e 's|^;*[[:space:]]*log_errors[[:space:]]*=.*|log_errors = On|' \
    -e 's|^;*[[:space:]]*error_reporting[[:space:]]*=.*|error_reporting = E_ALL|' \
    -e 's|^;*[[:space:]]*max_file_uploads[[:space:]]*=.*|max_file_uploads = 100|' \
    -e 's|^;*[[:space:]]*realpath_cache_size[[:space:]]*=.*|realpath_cache_size = 32M|' \
    -e 's|^;*[[:space:]]*realpath_cache_ttl[[:space:]]*=.*|realpath_cache_ttl = 120|' \
    "$PHP_INI"

  echo "✓ Updated: $PHP_INI"
done

# Configure OPcache
PHP_VERSION="8.5"

for OPCACHE_INI in /etc/php/${PHP_VERSION}/cli/conf.d/10-opcache.ini /etc/php/${PHP_VERSION}/fpm/conf.d/10-opcache.ini; do
  [ -f "$OPCACHE_INI" ] || continue

  sudo cp "$OPCACHE_INI" "$OPCACHE_INI.bak.$(date +%F-%H%M%S)"

  sudo sed -i \
    -e 's|^;*[[:space:]]*opcache.enable[[:space:]]*=.*|opcache.enable=1|' \
    -e 's|^;*[[:space:]]*opcache.enable_cli[[:space:]]*=.*|opcache.enable_cli=1|' \
    -e 's|^;*[[:space:]]*opcache.memory_consumption[[:space:]]*=.*|opcache.memory_consumption=256|' \
    -e 's|^;*[[:space:]]*opcache.interned_strings_buffer[[:space:]]*=.*|opcache.interned_strings_buffer=32|' \
    -e 's|^;*[[:space:]]*opcache.max_accelerated_files[[:space:]]*=.*|opcache.max_accelerated_files=50000|' \
    -e 's|^;*[[:space:]]*opcache.validate_timestamps[[:space:]]*=.*|opcache.validate_timestamps=1|' \
    -e 's|^;*[[:space:]]*opcache.revalidate_freq[[:space:]]*=.*|opcache.revalidate_freq=0|' \
    -e 's|^;*[[:space:]]*opcache.save_comments[[:space:]]*=.*|opcache.save_comments=1|' \
    "$OPCACHE_INI"

  echo "✓ Updated: $OPCACHE_INI"
done

sudo systemctl restart php8.5-fpm

# Verify PHP Configuration
echo "=== PHP Version ===" && php -v
echo ""
echo "=== PHP Settings ===" && php -i | grep -E "memory_limit|upload_max_filesize|post_max_size|max_input_vars|date.timezone|display_errors|display_startup_errors|log_errors|error_reporting|max_file_uploads|realpath_cache_size|realpath_cache_ttl|opcache"
echo ""
echo "=== PHP-FPM Status ===" && systemctl status php8.5-fpm --no-pager
```

---

## Install Composer

```bash
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php
php -r "unlink('composer-setup.php');"

sudo mv composer.phar /usr/local/bin/composer

echo 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

---

## Install Node.js & Bun

```bash
# Install Node.js
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.5/install.sh | bash
\. "$HOME/.nvm/nvm.sh"
nvm install 24

node -v
npm -v

# Install Bun
curl -fsSL https://bun.sh/install | bash
source /home/ora/.bashrc

bun -v
```

---

## MySQL Database

```bash
wget https://dev.mysql.com/get/mysql-apt-config_0.8.39-1_all.deb

echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.4-lts" \
  | sudo debconf-set-selections

sudo dpkg -i mysql-apt-config_0.8.39-1_all.deb
rm mysql-apt-config_0.8.39-1_all.deb

sudo apt update
sudo apt install -y mysql-server mysql-client

sudo systemctl enable --now mysql
systemctl status mysql --no-pager

# Configure Passwordless MySQL Root Access
echo -e "\n# Local development only: enable legacy auth plugin for passwordless root access\nmysql_native_password=ON" \
  | sudo tee -a /etc/mysql/mysql.conf.d/mysqld.cnf

sudo systemctl restart mysql

# Set passwordless root user
sudo mysql <<MYSQL_EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '';
FLUSH PRIVILEGES;
EXIT;
MYSQL_EOF

# Verify MySQL
mysql -u root -e "SELECT VERSION();"
```

---

## Apache Web Server

```bash
sudo apt install -y apache2

# Enable required modules
sudo a2enmod rewrite proxy_fcgi setenvif headers
sudo a2enconf php8.5-fpm

sudo systemctl restart apache2
systemctl status apache2 --no-pager
```

---

## phpMyAdmin Setup

Access phpMyAdmin at: `http://localhost/phpmyadmin`

```bash
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" \
  | sudo debconf-set-selections

sudo apt install -y phpmyadmin

# Enable Auto-Login
sudo tee /etc/phpmyadmin/conf.d/99-autologin.php > /dev/null <<'EOF'
<?php
$cfg['Servers'][1]['auth_type']       = 'config';
$cfg['Servers'][1]['user']            = 'root';
$cfg['Servers'][1]['password']        = '';
$cfg['Servers'][1]['AllowNoPassword'] = true;
EOF
```

---

## Git & GitHub CLI

```bash
# Install Git
sudo add-apt-repository ppa:git-core/ppa
sudo apt update && sudo apt install git
git --version

# Install GitHub CLI
sudo apt update
sudo apt install gh
gh --version

# Verify PGP key fingerprints (optional but recommended)
curl -fsSL -o - https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --show-keys

# Authenticate with GitHub
gh auth login
```

### Configure Git User Information

```bash
git config --global user.name "<YOUR_NAME>"
git config --global user.email "<YOUR_EMAIL>"

# Verify configuration
git config --global --list
```

### Configure Shell History

```bash
cat >> ~/.bashrc <<'EOF'

# Shell History Configuration
export HISTFILE=~/.bash_history
export HISTSIZE=10000
export HISTFILESIZE=0
EOF

source ~/.bashrc
```
