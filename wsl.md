# UBUNTU 26.04 LTS ON WSL2 — DEVELOPMENT ENVIRONMENT SETUP

## TARGET TECHNOLOGY STACK

| NO  | COMPONENT                                     | DESCRIPTION                                        |
| --- | --------------------------------------------- | -------------------------------------------------- |
| 01  | INSTALL AND CONFIGURE WSL2                    | Linux development environment on Windows           |
| 02  | INSTALL SYSTEM PACKAGES                       | Essential dependencies and development utilities   |
| 03  | CONFIGURE PHP 8.5                             | PHP runtime, extensions, FPM and OPcache           |
| 04  | INSTALL COMPOSER AND LARAVEL TOOLS            | PHP dependency manager, Laravel Installer and LSP  |
| 05  | INSTALL NODE.JS 24 LTS, BUN AND NPM UTILITIES | JavaScript runtime and package management          |
| 06  | CONFIGURE MYSQL 8.4 LTS                       | Relational database server and client              |
| 07  | CONFIGURE APACHE WITH PHP 8.5-FPM             | Web server with PHP-FPM integration                |
| 08  | CONFIGURE PHPMYADMIN                          | Web-based MySQL administration interface           |
| 09  | CONFIGURE AND VERIFY REDIS                    | In-memory caching and queue backend                |
| 10  | CONFIGURE GIT, SSH, GITHUB AND GITLAB         | Version control, SSH authentication and CLI tools  |
| 11  | CUSTOMIZE BASH SHELL                          | Shell history settings and custom terminal aliases |

### 01. INSTALL AND CONFIGURE WSL2

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

### 02. INSTALL SYSTEM PACKAGES

```bash
# 01. System Updates and Maintenance
sudo apt update
sudo apt full-upgrade -y
sudo apt autoclean
sudo apt autoremove --purge
# apt-cache policy <PKG_NAME>


# 02. PHP 8.5 Runtime and Extensions
sudo apt install -y --no-install-recommends \
    php8.5 php8.5-cli php8.5-fpm php8.5-common \
    php8.5-bcmath php8.5-curl php8.5-gd \
    php8.5-intl php8.5-mbstring php8.5-mysql \
    php8.5-readline php8.5-redis php8.5-sqlite3 \
    php8.5-xml php8.5-zip


# 03. Apache, MySQL, SQLite and Redis
sudo apt install -y --no-install-recommends \
    apache2 phpmyadmin \
    mysql-server mysql-client sqlite3 \
    redis-server redis-tools


# 04. Development Tools and Utilities
sudo apt install -y --no-install-recommends \
    ca-certificates curl openssl \
    gpg gnupg file \
    git gh glab composer \
    bind9-dnsutils iproute2 \
    rsync unzip zip zstd tree


# 05. System Monitoring Tools
sudo apt install -y --no-install-recommends \
    htop jq nano less
```

---

### 03. CONFIGURE PHP 8.5

```bash
# 01. Configure PHP Development Settings
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


# 02. Configure PHP OPcache
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


# 03. Enable and Verify PHP-FPM
sudo systemctl enable --now php8.5-fpm
sudo systemctl restart php8.5-fpm
```

---

### 04. INSTALL COMPOSER AND LARAVEL TOOLS

```bash
# 01. Configure Composer Global PATH
echo 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"' >> $HOME/.bashrc
source "$HOME/.bashrc"
composer --version


# 02. Install Laravel Installer and Laravel LSP
composer global require laravel/installer
composer global require laravel/lsp
laravel -v
```

---

### 05. INSTALL NODE.JS 24 LTS, BUN AND NPM UTILITIES

```bash
# 01. Install Node.js and npm Using NVM
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | bash
source "$HOME/.nvm/nvm.sh"
nvm install 24
nvm alias default 24
source "$HOME/.bashrc"
node --version
npm --version
nvm --version


# 02. Install Bun Runtime and Package Manager
curl -fsSL https://bun.sh/install | bash
source "$HOME/.bashrc"
bun --version


# 03. Install npm-check-updates Globally
npm install -g npm@12.2.0
npm install -g npm-check-updates
```

---

### 06. CONFIGURE MYSQL 8.4 LTS

```bash
# 01. Enable MySQL Service
sudo systemctl enable --now mysql


# 02. Configure MySQL Root Authentication
sudo mysql <<'SQL'
    ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '';
    FLUSH PRIVILEGES;
SQL


# 03. Verify MySQL Installation
mysql -u root -e "SELECT VERSION(), @@hostname, USER();"
```

---

### 07. CONFIGURE APACHE WITH PHP 8.5-FPM

```bash
# 01. Enable Apache Modules and PHP-FPM
sudo a2enmod rewrite headers proxy_fcgi setenvif
sudo a2dismod php8.5 2>/dev/null || true
sudo a2enconf php8.5-fpm
sudo systemctl enable --now apache2
sudo systemctl restart php8.5-fpm apache2
```

---

### 08. CONFIGURE PHPMYADMIN

```bash
# 01. Configure Apache Integration
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | sudo debconf-set-selections
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | sudo debconf-set-selections


# 02. Configure Automatic Login
sudo tee /etc/phpmyadmin/conf.d/99-autologin.php >/dev/null <<'EOF'
<?php
$cfg['Servers'][1]['auth_type']       = 'config';
$cfg['Servers'][1]['user']            = 'root';
$cfg['Servers'][1]['password']        = '';
$cfg['Servers'][1]['AllowNoPassword'] = true;
EOF


# 03. Install DarkOrange Theme
cd /usr/share/phpmyadmin/themes && sudo git clone https://github.com/atikhasan392/DarkOrange.git && cd ~
```

---

## 09. CONFIGURE AND VERIFY REDIS

```bash
# 01. Enable Redis and Verify Connection
sudo systemctl enable --now redis-server
redis-server --version
redis-cli ping
```

---

## 10. CONFIGURE GIT, SSH, GITHUB AND GITLAB

```bash
# 01. Set your Git identity and defaults
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


# 02. Create an SSH key only if one does not already exist
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -C "YOUR_EMAIL"
fi

chmod 600 "$HOME/.ssh/id_ed25519"
chmod 644 "$HOME/.ssh/id_ed25519.pub"


# 03. Start an SSH agent and load the key for this terminal session
eval "$(ssh-agent -s)"
ssh-add "$HOME/.ssh/id_ed25519"


# 04. Sign in to GitHub and configure SSH plus HTTPS Git access
gh auth login --hostname github.com --git-protocol ssh --web
gh config set git_protocol ssh --host github.com
gh auth setup-git --hostname github.com


# 05. Sign in to GitLab and configure SSH plus HTTPS Git access
glab auth login --hostname gitlab.com --web --git-protocol ssh --setup-git-credential-helper
glab config set git_protocol ssh --host gitlab.com


# 06. Add the public key to GitLab
glab ssh-key add "$HOME/.ssh/id_ed25519.pub" \
    --title "$(hostname -s)-$(date +%Y-%m-%d)" \
    --usage-type auth


# 07. Verify authentication
git config --global --list
gh auth status
glab auth status
ssh -T git@github.com
ssh -T git@gitlab.com
```

- GitHub: <https://github.com/settings/keys>
- GitLab: <https://gitlab.com/-/user_settings/ssh_keys>

---

### 11. CUSTOMIZE BASH SHELL

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
