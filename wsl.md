# UBUNTU 26.04 LTS ON WSL2 – DEVELOPMENT SETUP GUIDE

## TARGET STACK

| NO  | COMPONENT                                     | DESCRIPTION                                                     |
| --- | --------------------------------------------- | --------------------------------------------------------------- |
| 01  | INSTALL WSL2                                  | Install and configure WSL2 with Ubuntu on Windows.              |
| 02  | INSTALL APT PACKAGES                          | Install essential system packages, utilities, and dependencies. |
| 03  | CONFIGURE PHP 8.5                             | Install PHP 8.5 and configure required extensions and settings. |
| 04  | INSTALL NODE.JS 24 LTS & BUN                  | Install Node.js 24 LTS using NVM and set up Bun.                |
| 05  | CONFIGURE MYSQL 8.4 LTS                       | Install and configure MySQL 8.4 LTS for local development.      |
| 06  | CONFIGURE APACHE WITH PHP-FPM 8.5             | Configure Apache2 with PHP-FPM 8.5 for PHP applications.        |
| 07  | CONFIGURE PHPMYADMIN                          | Install and configure phpMyAdmin for MySQL database management. |
| 08  | CONFIGURE AND VERIFY REDIS                    | Install, configure, and verify Redis for caching and queues.    |
| 09  | CONFIGURE GIT, SSH, GITHUB CLI AND GITLAB CLI | Set up Git, SSH authentication, and GitHub/GitLab CLI tools.    |
| 10  | BASH HISTORY AND ALIASES                      | Customize Bash history behavior and terminal aliases.           |

---

### 01. INSTALL WSL2 (POWERSHELL — ADMINISTRATOR)

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

### 02. INSTALL APT PACKAGES

```bash
# 01. System Update, Upgrade & Maintenance
sudo apt update
sudo apt full-upgrade -y
sudo apt autoclean
sudo apt autoremove --purge
# apt-cache policy <PKG_NAME>


# 02. PHP 8.5 Runtime & Extensions
sudo apt install -y --no-install-recommends \
    php8.5 php8.5-cli php8.5-fpm php8.5-common \
    php8.5-bcmath php8.5-curl php8.5-gd \
    php8.5-intl php8.5-mbstring php8.5-mysql \
    php8.5-readline php8.5-redis php8.5-sqlite3 \
    php8.5-xml php8.5-zip


# 03. Web Server, Databases & Caching
sudo apt install -y --no-install-recommends \
    apache2 phpmyadmin \
    mysql-server mysql-client sqlite3 \
    redis-server redis-tools


# 04. Development Tools, Version Control & Utilities
sudo apt install -y --no-install-recommends \
    ca-certificates curl openssl \
    gpg gnupg file \
    git gh glab composer \
    bind9-dnsutils iproute2 \
    rsync unzip zip zstd tree


# 05. Terminal, Monitoring & Process Management
sudo apt install -y --no-install-recommends \
    htop jq nano less \
    cron supervisor
```

---

### 03. CONFIGURE PHP 8.5

```bash
# 01. Local development settings
cat > /tmp/99-local-dev.ini <<'EOF'
; LOCAL DEVELOPMENT OVERRIDES
memory_limit           = 512M
max_execution_time     = 120
max_input_time         = 120
max_input_vars         = 10000
file_uploads           = On
upload_max_filesize    = 1024M
post_max_size          = 1100M
max_file_uploads       = 50
default_socket_timeout = 60
date.timezone          = Asia/Dhaka
display_errors         = On
display_startup_errors = On
log_errors             = On
error_reporting        = E_ALL
html_errors            = On
realpath_cache_size    = 16M
realpath_cache_ttl     = 120
EOF

sudo install -m 644 /tmp/99-local-dev.ini /etc/php/8.5/cli/conf.d/99-local-dev.ini
sudo install -m 644 /tmp/99-local-dev.ini /etc/php/8.5/fpm/conf.d/99-local-dev.ini

# 02. OPcache overrides
cat > /tmp/99-local-opcache.ini <<'EOF'
; LOCAL OPCACHE OVERRIDES
opcache.enable                  = 1
opcache.enable_cli              = 0
opcache.memory_consumption      = 256
opcache.interned_strings_buffer = 32
opcache.max_accelerated_files   = 32531
opcache.max_wasted_percentage   = 5
opcache.validate_timestamps     = 1
opcache.revalidate_freq         = 0
opcache.file_update_protection  = 0
opcache.save_comments           = 1
opcache.enable_file_override    = 0
opcache.use_cwd                 = 1
opcache.validate_permission     = 0
EOF

sudo install -m 644 /tmp/99-local-opcache.ini /etc/php/8.5/cli/conf.d/99-local-opcache.ini
sudo install -m 644 /tmp/99-local-opcache.ini /etc/php/8.5/fpm/conf.d/99-local-opcache.ini

# 03. Enable FPM and verify
sudo systemctl enable --now php8.5-fpm
sudo systemctl restart php8.5-fpm
```

---

### 04. INSTALL NODE.JS 24 LTS & BUN

```bash
# Install node.js or npm
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | bash

export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"

nvm install 24
nvm alias default 24

# Install bun
curl -fsSL https://bun.sh/install | bash
source /home/ora/.bashrc
```

---

### 05. CONFIGURE MYSQL 8.4 LTS

```bash
sudo systemctl enable --now mysql

# Configure Passwordless Root Access
sudo mysql <<'SQL'
    ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '';
    FLUSH PRIVILEGES;
SQL

# Verify MySQL
mysql -u root -e "SELECT VERSION(), @@hostname, USER();"
```

---

### 06. CONFIGURE APACHE WITH PHP-FPM 8.5

```bash
sudo a2enmod rewrite headers proxy_fcgi setenvif
sudo a2dismod php8.5 2>/dev/null || true
sudo a2enconf php8.5-fpm
sudo systemctl enable --now apache2
sudo systemctl restart php8.5-fpm apache2
```

---

### 07. CONFIGURE PHPMYADMIN

```bash
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | sudo debconf-set-selections
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | sudo debconf-set-selections

# Enable Auto-Login
sudo tee /etc/phpmyadmin/conf.d/99-autologin.php >/dev/null <<'EOF'
<?php
$cfg['Servers'][1]['auth_type']       = 'config';
$cfg['Servers'][1]['user']            = 'root';
$cfg['Servers'][1]['password']        = '';
$cfg['Servers'][1]['AllowNoPassword'] = true;
EOF

cd /usr/share/phpmyadmin/themes && sudo git clone https://github.com/atikhasan392/DarkOrange.git && cd ~
```

---

## 08. CONFIGURE AND VERIFY REDIS

```bash
sudo systemctl enable --now redis-server
redis-server --version
redis-cli ping
```

---

## 09. CONFIGURE GIT, SSH, GITHUB CLI AND GITLAB CLI

```bash
# 01. Git identity and defaults
git config --global user.name "YOUR_NAME"
git config --global user.email "YOUR_EMAIL"
git config --global init.defaultBranch main
git config --global core.autocrlf input
git config --global core.editor nano
git config --global fetch.prune true
git config --global pull.rebase false
git config --global push.autoSetupRemote true

git config --global --list

#02. One SSH key for GitHub and GitLab
mkdir -p ~/.ssh
chmod 700 ~/.ssh

if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "YOUR_EMAIL"
fi

cat ~/.ssh/id_ed25519.pub

# 03. GitHub CLI
gh auth login --hostname github.com --git-protocol ssh --web
gh auth status
gh config list

# 04. GitLab CLI
glab auth login
glab auth status
glab config list

# 05. Verify SSH
ssh -T git@github.com
ssh -T git@gitlab.com
```

- GitHub: <https://github.com/settings/keys>
- GitLab: <https://gitlab.com/-/user_settings/ssh_keys>

---

### 10. BASH HISTORY AND ALIASES

```bash
cat >> ~/.bashrc <<'EOF'

# --------------------------------------------------
# BASH HISTORY
# --------------------------------------------------
export HISTFILE=/dev/null
export HISTSIZE=5000
export HISTCONTROL=ignoreboth:erasedups
unset HISTIGNORE
shopt -s histappend
trap 'history -c' EXIT

# --------------------------------------------------
# TERMINAL ALIASES
# --------------------------------------------------
alias cls='clear'
EOF

source ~/.bashrc
```
