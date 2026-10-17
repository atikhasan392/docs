# WSL2 OR UBUNTU 26.04 LTS - SETUP GUIDE

| COMPONENT                     | VERSION             | PURPOSE                                                          |
| ----------------------------- | ------------------- | ---------------------------------------------------------------- |
| WSL2                          | Latest stable       | Run a native Linux development environment within Windows        |
| Ubuntu                        | 26.04 LTS           | Primary Linux operating system for development                   |
| PHP (CLI + FPM)               | 8.5 NTS (FPM + CLI) | Execute Laravel applications, CLI commands, and PHP requests     |
| Composer / Laravel Installer  | Latest stable       | Manage PHP dependencies and scaffold Laravel projects            |
| MySQL                         | 8.4 LTS             | Store, manage, and query relational application data             |
| Apache                        | 2.4.x               | Serve local websites and process PHP requests through PHP-FPM    |
| phpMyAdmin                    | Repository version  | Manage MySQL databases through a web-based interface             |
| Node.js                       | 24 LTS              | Run JavaScript tooling, development servers, and frontend builds |
| Bun                           | Latest stable       | Execute JavaScript and manage frontend dependencies efficiently  |
| Git / GitHub CLI / GitLab CLI | Latest compatible   | Manage source control, repositories, and GitHub/GitLab workflows |

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

### 02. INSTALL BASE PACKAGES

```bash
sudo apt update && sudo apt full-upgrade -y

sudo apt install -y --no-install-recommends \
    bash-completion build-essential ca-certificates curl dnsutils file git gnupg htop jq \
    lsb-release nano net-tools openssl rsync software-properties-common tree unzip vim wget zip zstd \
    acl cron git-lfs inotify-tools libnss3-tools sqlite3 supervisor tmux

sudo apt autoremove --purge -y && sudo apt autoclean
sudo timedatectl set-timezone Asia/Dhaka
sudo apt update
```

---

### 03. INSTALL PHP 8.5, PHP-FPM & PHP-CLI

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

# enable & start php-fpm
sudo systemctl enable --now php8.5-fpm
systemctl status php8.5-fpm --no-pager

# configure php for local development
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

    echo "UPDATED: $PHP_INI"
done

# configure OPcache
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

    echo "UPDATED: $OPCACHE_INI"
done

sudo systemctl restart php8.5-fpm

# verify php configuration
echo "=== PHP VERSION ===" && php -v
echo "=== PHP VERSION ==="
echo "=== PHP SETTINGS ===" && php -i | grep -E "memory_limit|upload_max_filesize|post_max_size|max_input_vars|date.timezone|display_errors|display_startup_errors|log_errors|error_reporting|max_file_uploads|realpath_cache_size|realpath_cache_ttl|opcache"
echo "=== PHP SETTINGS ==="
echo "=== PHP-FPM STATUS ===" && systemctl status php8.5-fpm --no-pager
echo "=== PHP-FPM STATUS ==="
```

---

### 04. INSTALL COMPOSER & LARAVEL INSTALLER

```bash
# Install Composer
sudo apt update
curl -fsSL https://getcomposer.org/installer -o composer-setup.php
php composer-setup.php --install-dir="$HOME/.local/bin" --filename=composer
rm composer-setup.php
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.config/composer/vendor/bin:$PATH"
composer --version

# Install Laravel Installer
sudo apt update
composer global require laravel/installer
composer global require laravel/lsp
export PATH="$HOME/.config/composer/vendor/bin:$PATH"

laravel --version
```

---

### 05. INSTALL NODE.JS, NPM & BUN

```bash
# Install Node.js
sudo apt update
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | bash
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
nvm install 24
node -v
npm -v

# Install Bun
sudo apt update
curl -fsSL https://bun.sh/install | bash
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
bun -v
```

---

### 06. INSTALL MYSQL DATABASE

```bash
sudo apt update
sudo apt install -y mysql-server mysql-client
sudo systemctl enable --now mysql

# Configure Passwordless Root Access (Local Development Only)
sudo mysql <<'SQL'
ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '';
FLUSH PRIVILEGES;
SQL

# Verify MySQL
mysql -u root -e "SELECT VERSION(), @@hostname, USER();"
systemctl status mysql --no-pager
```

---

### 07. INSTALL APACHE WEB SERVER

```bash
sudo apt update
sudo apt install -y apache2

sudo a2enmod rewrite proxy_fcgi setenvif headers ssl
sudo a2enconf php8.5-fpm

sudo apache2ctl configtest
sudo php-fpm8.5 -t

sudo systemctl enable --now php8.5-fpm apache2
sudo systemctl restart php8.5-fpm apache2

systemctl is-active apache2 php8.5-fpm
```

---

### 08. INSTALL PHPMYADMIN & SETUP

```bash
# Install phpMyAdmin
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" \
	| sudo debconf-set-selections
  

sudo apt update
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

### 09. INSTALL GIT, GITHUB CLI & GITLAB CLI

```bash
# Install Dependencies
sudo apt update
sudo apt install -y git gh glab openssh-client

# Configure Git Identity
git config --global user.name >/dev/null || {
    read -rp "Git Username: " GIT_NAME
    git config --global user.name "$GIT_NAME"
}

git config --global user.email >/dev/null || {
    read -rp "Git Email: " GIT_EMAIL
    git config --global user.email "$GIT_EMAIL"
}

# Configure Git Defaults
git config --global init.defaultBranch main
git config --global core.autocrlf input
git config --global fetch.prune true
git config --global push.autoSetupRemote true

# Configure SSH
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

SSH_KEY="$HOME/.ssh/id_ed25519"

if [[ ! -f "$SSH_KEY" ]]; then
    ssh-keygen -t ed25519 \
        -C "$(git config --global user.email)" \
        -f "$SSH_KEY"
fi

# Start SSH Agent & Add Key
if [[ -z "${SSH_AUTH_SOCK:-}" ]] || ! ssh-add -l >/dev/null 2>&1; then
    eval "$(ssh-agent -s)"
fi

ssh-add "$SSH_KEY"

# Authenticate GitHub & GitLab
gh auth status || gh auth login
glab auth status || glab auth login

# Verify Installation
printf '\n=== INSTALLED VERSIONS ===\n'
git --version
gh --version | head -n 1
glab --version | head -n 1
ssh -V

printf '\n=== GIT CONFIGURATION ===\n'
git config --global --list

printf '\n=== SSH PUBLIC KEY ===\n'
cat "${SSH_KEY}.pub"
```

> Set the SSH public key in these two places:
>
> - [GitHub SSH Keys](https://github.com/settings/keys)
> - [GitLab SSH Keys](https://gitlab.com/-/user_settings/ssh_keys)

---

### 10. CONFIGURE SHELL HISTORY & TERMINAL ALIASES

```bash
# Shell History Configuration
export HISTFILE="$HOME/.bash_history"
export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# Remove failed commands from history
__history_filter() {
    local exit_code=$?
    local history_entry

    if (( exit_code == 127 )); then
        history_entry=$(HISTTIMEFORMAT= history 1)
        history_entry="${history_entry%%[![:space:][:digit:]]*}"
        history_entry="${history_entry//[[:space:]]/}"

        if [[ -n "$history_entry" ]]; then
            history -d "$history_entry"
        fi
    fi

    return 0
}

PROMPT_COMMAND="__history_filter${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

# Terminal Aliases
alias cls='clear'
```
