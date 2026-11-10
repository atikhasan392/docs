# UBUNTU 26.04 LTS ON WSL2 — PROFESSIONAL DEVELOPMENT ENVIRONMENT SETUP

## 01. WSL2 INSTALLATION & UBUNTU DISTRIBUTION MANAGEMENT

```powershell
wsl --install
wsl --update
wsl --list --online
wsl --install -d Ubuntu-26.04
wsl --list --verbose

# ⚠️ WARNING: Permanently deletes the distribution and its files
# wsl --unregister Ubuntu-26.04
```

---

## 02. SYSTEM PACKAGES & DEVELOPMENT DEPENDENCIES INSTALLATION

```bash
# 01. System Updates & Maintenance
sudo apt update
sudo apt full-upgrade -y
sudo apt autoclean
sudo apt autoremove --purge -y
# apt-cache policy <PKG_NAME>


# 02. PHP 8.5 Runtime & Extensions
sudo apt install -y --no-install-recommends \
    php8.5 php8.5-cli php8.5-fpm php8.5-common \
    php8.5-bcmath php8.5-curl php8.5-gd \
    php8.5-intl php8.5-mbstring php8.5-mysql \
    php8.5-readline php8.5-redis php8.5-sqlite3 \
    php8.5-xml php8.5-zip


# 03. Python 3 Runtime & Development Tools
sudo apt install -y --no-install-recommends \
    python3-full python3-pip python3-dev \
    python3-venv python3-wheel python3-setuptools \
    python3-pip-whl python3-setuptools-whl


# 04. Web Server & Database Services
sudo apt install -y --no-install-recommends \
    apache2 sqlite3 \
    mysql-server mysql-client \
    redis-server redis-tools


# 05. Database Administration Tools
sudo apt install -y --no-install-recommends \
    phpmyadmin sqlitebrowser


# 06. Development Tools & Package Managers
sudo apt install -y --no-install-recommends \
    git gh glab composer


# 07. System Utilities & Networking
sudo apt install -y --no-install-recommends \
    curl wget gpg file tree zip unzip \
    ca-certificates bind9-dnsutils \
    iproute2 rsync zstd


# 08. System Monitoring & Terminal Tools
sudo apt install -y --no-install-recommends \
    htop nano less
```

---

## 02. PHP 8.5 RUNTIME & PHP-FPM CONFIGURATION

```bash
# 01. PHP 8.5 - WSL2 Local Development
cat > /tmp/99-local-dev.ini <<'EOF'
; Resource Limits
memory_limit                    = 512M
max_execution_time              = 120
max_input_time                  = 120
max_input_vars                  = 10000

; File Uploads
file_uploads                    = On
upload_max_filesize             = 1024M
post_max_size                   = 1100M
max_file_uploads                = 50

; General
default_socket_timeout          = 60
date.timezone                   = Asia/Dhaka
short_open_tag                  = Off

; Error Reporting
display_errors                  = On
display_startup_errors          = On
log_errors                      = On
error_reporting                 = E_ALL
html_errors                     = On

; Realpath Cache
realpath_cache_size             = 16M
realpath_cache_ttl              = 120

; Assertions
zend.assertions                 = 1
assert.exception                = 1

; OPcache
opcache.enable                  = 1
opcache.enable_cli              = 0
opcache.memory_consumption      = 256
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files   = 32531
opcache.max_wasted_percentage   = 5
opcache.validate_timestamps     = 1
opcache.revalidate_freq         = 0
opcache.save_comments           = 1
EOF

sudo install -m 644 /tmp/99-local-dev.ini /etc/php/8.5/cli/conf.d/99-local-dev.ini
sudo install -m 644 /tmp/99-local-dev.ini /etc/php/8.5/fpm/conf.d/99-local-dev.ini


# 02. Enable & Restart PHP-FPM
sudo systemctl enable --now php8.5-fpm
sudo systemctl restart php8.5-fpm
```

## 04. COMPOSER & LARAVEL DEVELOPMENT TOOLS INSTALLATION

```bash
# 01. Configure Composer Global PATH
echo 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"' >> $HOME/.bashrc
source "$HOME/.bashrc"
composer --version


# 02. Install Laravel Installer & Laravel LSP
composer global require laravel/installer
composer global require laravel/lsp
laravel -v
```

## 05. NODE.JS 26 LTS, NVM & BUN RUNTIME CONFIGURATION

```bash
# 01. Install Node.js & NPM Using NVM
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.41.0/install.sh | bash
source "$HOME/.nvm/nvm.sh"
nvm install 26
nvm alias default 26
source "$HOME/.bashrc"
node --version
npm --version
nvm --version


# 02. Install Bun Runtime & Package Manager
curl -fsSL https://bun.sh/install | bash
source "$HOME/.bashrc"
bun --version


# 03. Install npm-check-updates Globally
npm install -g npm@12.2.0
npm install -g npm-check-updates
```

## 06. MYSQL 8.4 LTS INSTALLATION & DATABASE CONFIGURATION

```bash
# 01. Enable & Restart MySQL Service
sudo systemctl enable --now mysql
sudo systemctl restart mysql


# 02. Configure MySQL Root Authentication
sudo mysql <<'SQL'
    ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '';
    FLUSH PRIVILEGES;
SQL


# 03. Verify MySQL Installation
mysql -u root -e "SELECT VERSION(), @@hostname, USER();"
```

## 07. APACHE2 WEB SERVER & PHP-FPM INTEGRATION

```bash
# 01. Enable Apache Modules & PHP-FPM
sudo a2enmod rewrite headers proxy_fcgi setenvif
sudo a2dismod php8.5 2>/dev/null || true
sudo a2enconf php8.5-fpm


# 02. Configure MySQL Root Authentication
sudo mysql <<'SQL'
    ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '';
    FLUSH PRIVILEGES;
SQL


# 02. Enable & Restart Services
sudo systemctl enable --now php8.5-fpm apache2
sudo systemctl restart php8.5-fpm apache2
```

## 08. PHPMYADMIN INSTALLATION & ADMINISTRATION CONFIGURATION

```bash
# 01. Configure Apache Integration
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | sudo debconf-set-selections
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | sudo debconf-set-selections


# 02. Configure Automatic Login
cat > /tmp/99-autologin.php <<'EOF'
<?php
$cfg['Servers'][1]['auth_type']       = 'config';
$cfg['Servers'][1]['user']            = 'root';
$cfg['Servers'][1]['password']        = '';
$cfg['Servers'][1]['AllowNoPassword'] = true;
EOF

sudo install -m 644 /tmp/99-autologin.php /etc/phpmyadmin/conf.d/99-autologin.php


# 03. Install DarkOrange Theme
cd /usr/share/phpmyadmin/themes && sudo git clone https://github.com/atikhasan392/DarkOrange.git
cd $HOME
```

## 09. REDIS SERVER INSTALLATION & CONNECTION VERIFICATION

```bash
# 01. Enable Redis & Verify Connection
sudo systemctl enable --now redis-server
redis-server --version
redis-cli ping
```

## 10. GIT VERSION CONTROL, SSH & GITHUB/GITLAB AUTHENTICATION

```bash
# 01. Git Global Configuration
git config --global user.name "ATik HaSan"
git config --global user.email "YOUR_EMAIL"
git config --global init.defaultBranch main
git config --global core.autocrlf input
git config --global core.editor nano
git config --global fetch.prune true
git config --global pull.rebase true
git config --global rebase.autoStash true
git config --global push.default simple
git config --global push.autoSetupRemote true
git config --global rerere.enabled true


# 02. Generate SSH Keys
mkdir -p ~/.ssh && chmod 700 ~/.ssh

ssh-keygen -t ed25519 -C "YOUR_EMAIL" -f ~/.ssh/id_ed25519_github
ssh-keygen -t ed25519 -C "YOUR_EMAIL" -f ~/.ssh/id_ed25519_gitlab


# 03. Configure SSH Hosts
cat > ~/.ssh/config <<'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes
    AddKeysToAgent yes

Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile ~/.ssh/id_ed25519_gitlab
    IdentitiesOnly yes
    AddKeysToAgent yes
EOF

chmod 600 ~/.ssh/config


# 04. Configure SSH Agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_github
ssh-add ~/.ssh/id_ed25519_gitlab


# 05. Display Public SSH Keys
echo "GITHUB PUBLIC KEY:"
cat ~/.ssh/id_ed25519_github.pub

echo "GITLAB PUBLIC KEY:"
cat ~/.ssh/id_ed25519_gitlab.pub

# Add keys:
# https://github.com/settings/keys
# https://gitlab.com/-/user_settings/ssh_keys


# 06. GIthub Authentication
gh auth login
gh auth setup-git


# 07. Gitlab Authentication
glab auth login


# 08. Verify Configuration
git config --global --list
ssh -T git@github.com
ssh -T git@gitlab.com
gh auth status
glab auth status
```

## 11. CLOUDFLARE TUNNEL INSTALLATION & SERVICE CONFIGURATION

```bash
# 01. Add cloudflare gpg key
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null


# 02. Add this repo to your apt repositories
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list


# 03. Install Cloudflared
sudo apt-get update && sudo apt-get install cloudflared


# 04. Install as service
# sudo cloudflared service install **********************************************
```

## 12. BASH SHELL CUSTOMIZATION & ENVIRONMENT OPTIMIZATION

```bash
# 01. Configure Bash History and Terminal Aliases
cat >> $HOME/.bashrc <<'EOF'

# Shell History Configuration
export HISTFILE=/dev/null
export HISTSIZE=5000
export HISTCONTROL=ignoreboth:erasedups
unset HISTIGNORE

# Custom Terminal Aliases
alias cls='clear'
EOF

source "$HOME/.bashrc"
# nano "$HOME/.bashrc"
```
