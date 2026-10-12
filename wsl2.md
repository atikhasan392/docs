# Laravel Development Environment Setup

**Ubuntu 26.04 LTS / WSL2 — Local Development Only**

> [!WARNING]
> This guide is intended **only for a local development machine**. It enables verbose PHP errors and uses development database credentials. Do not copy these settings to a public or production server.

## Stack

| Component                   | Target                     |
| --------------------------- | -------------------------- |
| Ubuntu                      | 26.04 LTS (native or WSL2) |
| PHP                         | 8.5 CLI and PHP-FPM        |
| Composer                    | Latest stable              |
| Laravel Installer           | Latest stable              |
| MySQL                       | 8.4 LTS                    |
| Apache                      | 2.4 with PHP-FPM           |
| Node.js                     | 24 LTS via nvm             |
| Bun                         | Latest stable              |
| Git, GitHub CLI, GitLab CLI | Distribution packages      |
| phpMyAdmin                  | Optional                   |

**Requirements:** A fresh Ubuntu 26.04 installation, sudo access, approximately 10 GB of free space, and basic terminal familiarity. Check package availability before installation; package versions and installer URLs can change.

## 1. Install Ubuntu on WSL2 (Windows Only)

Run in **PowerShell as Administrator**:

```powershell
wsl --update
wsl --list --online
wsl --install -d Ubuntu-26.04
```

Launch Ubuntu and verify the environment:

```bash
cat /etc/os-release
ps -p 1 -o comm=
```

If the second command does not show `systemd`, enable it:

```bash
sudo tee /etc/wsl.conf > /dev/null <<'EOF_SYSTEMD'
[boot]
systemd=true
EOF_SYSTEMD
```

Then run `wsl --shutdown` in PowerShell and reopen Ubuntu.

> [!TIP]
> Store projects in the Linux filesystem (for example, `~/projects`), not under `/mnt/c`, for better filesystem performance.

## 2. Update Ubuntu and Install Utilities

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y \
  ca-certificates curl wget gnupg \
  software-properties-common \
  git unzip zip zstd build-essential \
  tree htop acl
```

## 3. Install PHP 8.5 and Extensions

First verify the packages are available:

```bash
apt-cache policy php8.5-cli php8.5-fpm mysql-server
```

Install PHP and the common Laravel extensions:

```bash
sudo apt install -y \
  php8.5-cli php8.5-fpm \
  php8.5-bcmath php8.5-curl php8.5-gd \
  php8.5-intl php8.5-mbstring php8.5-mysql \
  php8.5-xml php8.5-zip php8.5-sqlite3
```

Add optional extensions only when needed (for example, Redis, PostgreSQL, or Imagick).

Create a dedicated development configuration instead of repeatedly editing the distribution's `php.ini`:

```bash
sudo tee /etc/php/8.5/mods-available/local-dev.ini > /dev/null <<'EOF_PHP'
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
EOF_PHP

sudo phpenmod -v 8.5 -s cli local-dev
sudo phpenmod -v 8.5 -s fpm local-dev
sudo systemctl enable --now php8.5-fpm
sudo systemctl restart php8.5-fpm

php -v
php --ini
php -m
```

The `local-dev.ini` filename sorts after the default OPcache configuration, so its overrides take precedence. CLI OPcache is disabled because short-lived CLI processes rarely benefit from it.

## 4. Install Composer and Laravel Installer

Verify Composer's installer before running it:

```bash
EXPECTED_SIGNATURE="$(curl -fsSL https://composer.github.io/installer.sig)"
curl -fsSL https://getcomposer.org/installer -o composer-setup.php
ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then
  echo "Composer installer verification failed" >&2
  rm -f composer-setup.php
  exit 1
fi

php composer-setup.php --install-dir=/tmp --filename=composer
sudo mv /tmp/composer /usr/local/bin/composer
rm -f composer-setup.php

composer --version
```

Install the Laravel installer and ensure Composer's global binaries are on `PATH`:

```bash
composer global require laravel/installer

COMPOSER_BIN="$(composer global config bin-dir --absolute)"
export PATH="$COMPOSER_BIN:$PATH"

if ! grep -Fq 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"' "$HOME/.bashrc"; then
  echo 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"' >> "$HOME/.bashrc"
fi

laravel --version
```

> [!NOTE]
> The default Composer global binary path is `~/.config/composer/vendor/bin` on many Linux installations. If `composer global config bin-dir --absolute` prints a different path, persist that actual path in your shell configuration instead.

## 5. Install Node.js 24 LTS and Bun

Use the official nvm project. The installer tag below is an example; verify the current release before running it.

```bash
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | bash
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"

nvm install 24
nvm alias default 24
node -v
npm -v
```

Install Bun:

```bash
curl -fsSL https://bun.sh/install | bash
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
bun -v
```

Open a new terminal after installation to confirm both commands are available without manually exporting environment variables.

## 6. Install MySQL 8.4

```bash
sudo apt install -y mysql-server mysql-client
sudo systemctl enable --now mysql

mysql --version
sudo mysql -Nse 'SELECT VERSION();'
```

**Verify that the installed server is MySQL 8.4.x.** Do not assume the unversioned `mysql-server` package always installs the same release on every Ubuntu version or mirror.

Keep Ubuntu's local administrative socket authentication instead of enabling the deprecated `mysql_native_password` plugin or assigning an empty password to MySQL root.

Create a project database and a dedicated user:

```bash
sudo mysql <<'EOF_SQL'
CREATE DATABASE IF NOT EXISTS laravel_dev
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'laravel'@'localhost'
  IDENTIFIED BY 'change-this-local-password';

GRANT ALL PRIVILEGES ON laravel_dev.*
  TO 'laravel'@'localhost';
EOF_SQL
```

Replace the example password with your own local-only password. For existing users, `CREATE USER IF NOT EXISTS` does not update an existing password; use `ALTER USER` explicitly when necessary.

Configure the Laravel project's `.env`:

```dotenv
APP_ENV=local
APP_DEBUG=true
APP_URL=http://localhost:8000

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel_dev
DB_USERNAME=laravel
DB_PASSWORD=change-this-local-password
```

Check connectivity:

```bash
mysql -h 127.0.0.1 -u laravel -p laravel_dev -e 'SELECT DATABASE();'
```

## 7. Install Apache with PHP-FPM

```bash
sudo apt install -y apache2
sudo a2enmod rewrite proxy_fcgi setenvif headers
sudo a2enconf php8.5-fpm

sudo apache2ctl configtest
sudo systemctl enable --now apache2
sudo systemctl restart apache2
```

Open <http://localhost> to check Apache's default page.

Apache is optional if you only use `php artisan serve` or `composer run dev`. For Apache-hosted Laravel projects, the document root **must** point to the project's `public` directory.

## 8. Optional: Install phpMyAdmin

```bash
sudo apt install -y phpmyadmin
```

Select Apache integration if the package installer offers it. If the Apache configuration is present but not enabled:

```bash
if [ -f /etc/apache2/conf-available/phpmyadmin.conf ]; then
  sudo a2enconf phpmyadmin
elif [ -f /etc/phpmyadmin/apache.conf ]; then
  sudo ln -s /etc/phpmyadmin/apache.conf \
    /etc/apache2/conf-available/phpmyadmin.conf
  sudo a2enconf phpmyadmin
fi

sudo apache2ctl configtest
sudo systemctl reload apache2
```

Open <http://localhost/phpmyadmin> and log in with the dedicated `laravel` database user. Do **not** configure automatic MySQL root login. phpMyAdmin packaging and Apache integration can vary; verify that the URL is actually reachable.

## 9. Install and Configure Git CLIs

```bash
sudo apt install -y git gh glab

git --version
gh --version
glab --version

git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
```

Authenticate when needed:

```bash
gh auth login
glab auth login
```

Optional SSH setup:

```bash
ssh-keygen -t ed25519 -C "you@example.com"
cat ~/.ssh/id_ed25519.pub
```

Add the public key to the relevant account, then test:

```bash
ssh -T git@github.com
ssh -T git@gitlab.com
```

An SSH authentication test can return a nonzero exit status even when it reports successful authentication; read the message.

## 10. Create a Laravel Project

```bash
mkdir -p ~/projects
cd ~/projects
laravel new example-app
cd example-app
```

Follow the installer's prompts, configure the database credentials in `.env`, and then run:

```bash
php artisan key:generate
php artisan migrate
bun install
bun run build
```

If your generated `composer.json` defines a `dev` script:

```bash
composer run dev
```

Otherwise, start the Laravel application directly:

```bash
php artisan serve
```

Open <http://localhost:8000> when using Laravel's development server. When running the Vite development server separately, use `bun run dev` in another terminal.

## 11. Optional: Apache Virtual Host

Use this only if you prefer a project domain such as `example-app.test` over Laravel's built-in development server.

```bash
PROJECT_PATH="$HOME/projects/example-app"

sudo tee /etc/apache2/sites-available/example-app.conf > /dev/null <<EOF_VHOST
<VirtualHost *:80>
    ServerName example-app.test
    DocumentRoot "$PROJECT_PATH/public"

    <Directory "$PROJECT_PATH/public">
        AllowOverride All
        Require all granted
        Options FollowSymLinks
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/example-app-error.log
    CustomLog \${APACHE_LOG_DIR}/example-app-access.log combined
</VirtualHost>
EOF_VHOST

sudo a2ensite example-app.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
```

For WSL2, add the following entry to the **Windows** hosts file (`C:\Windows\System32\drivers\etc\hosts`) using an editor started as Administrator:

```text
127.0.0.1 example-app.test
```

Set the project's `APP_URL=http://example-app.test` and clear cached configuration if needed:

```bash
php artisan config:clear
```

Apache must be able to traverse the home/project directories and write to Laravel's runtime directories. Apply targeted ACLs rather than `chmod -R 777`:

```bash
sudo setfacl -m u:www-data:--x "$HOME"
sudo setfacl -m u:www-data:--x "$HOME/projects"
sudo setfacl -R -m u:www-data:rX "$PROJECT_PATH"
sudo setfacl -R -m u:www-data:rwX \
  "$PROJECT_PATH/storage" \
  "$PROJECT_PATH/bootstrap/cache"
sudo setfacl -dR -m u:www-data:rwX \
  "$PROJECT_PATH/storage" \
  "$PROJECT_PATH/bootstrap/cache"
```

Ensure `PROJECT_PATH` is still set in the current shell when running the ACL commands. If Apache reports 403 or 500 errors, inspect the project's Apache error log and check directory permissions and PHP-FPM status. For collaborative projects, a shared group and consistent umask may be preferable to ACLs.

## 12. Final Verification

```bash
echo '=== OS ==='
lsb_release -a

echo '=== PHP ==='
php -v
php -m | grep -Ei 'bcmath|curl|gd|intl|mbstring|pdo_mysql|zip|opcache'

echo '=== Composer / Laravel ==='
composer --version
laravel --version

echo '=== MySQL ==='
sudo mysql -Nse 'SELECT VERSION();'

echo '=== Apache ==='
apache2 -v
sudo apache2ctl configtest

echo '=== JavaScript ==='
node -v
npm -v
bun -v

echo '=== Git CLIs ==='
git --version
gh --version
glab --version

echo '=== Services ==='
for service in mysql apache2 php8.5-fpm; do
  printf '%s: ' "$service"
  systemctl is-active "$service"
done
```

For an end-to-end Laravel check, run `php artisan migrate:status`, open the application in a browser, and verify a database-backed route or feature.

## Troubleshooting

| Symptom                               | Check                                                                          |
| ------------------------------------- | ------------------------------------------------------------------------------ |
| PHP 8.5 packages not found            | `apt update`, `apt-cache policy`, Ubuntu release and enabled repositories      |
| MySQL is not 8.4.x                    | `sudo mysql -Nse 'SELECT VERSION();'`; review package source before proceeding |
| `systemctl` does not work in WSL2     | Enable systemd in `/etc/wsl.conf`, then `wsl --shutdown`                       |
| `laravel`, `node`, or `bun` not found | Open a new shell and inspect `PATH`, nvm and Bun initialization                |
| Laravel database connection fails     | Check `.env`, MySQL service, user grants, host and password                    |
| Apache 403                            | Confirm `DocumentRoot` points to `public` and directory traversal permissions  |
| Apache 500                            | Check Apache error logs, Laravel logs, and PHP-FPM status                      |
| phpMyAdmin 404                        | Check whether its Apache configuration is installed and enabled                |
| Frontend assets missing               | Run `bun install` and `bun run build` or start the Vite development server     |

## Security and Maintenance Notes

- Never expose this configuration directly to the internet.
- Use separate MySQL databases and users for different projects.
- Keep MySQL root's local socket authentication; do not enable empty-password root logins.
- Keep `APP_DEBUG=true` strictly for local development.
- Avoid globally increasing upload limits beyond what your applications need.
- Install Redis, Xdebug, PostgreSQL or Imagick only when required.
- Back up your projects and databases before major Ubuntu or MySQL upgrades.
- Recheck official documentation and package versions periodically; this guide is not a substitute for testing on your specific machine.

## Official References

- [Ubuntu documentation](https://documentation.ubuntu.com/)
- [Microsoft WSL documentation](https://learn.microsoft.com/windows/wsl/)
- [PHP documentation](https://www.php.net/manual/en/)
- [Composer download and installer verification](https://getcomposer.org/download/)
- [Laravel documentation](https://laravel.com/docs)
- [MySQL 8.4 reference manual](https://dev.mysql.com/doc/refman/8.4/en/)
- [Apache HTTP Server documentation](https://httpd.apache.org/docs/2.4/)
- [phpMyAdmin documentation](https://docs.phpmyadmin.net/)
- [nvm releases](https://github.com/nvm-sh/nvm/releases)
- [Bun documentation](https://bun.sh/docs)
