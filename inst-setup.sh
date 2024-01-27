#!/bin/bash
touch /home/ubuntu/.bash_aliases
mkdir -p /var/www/html/front.mmi.run/
echo "alias userdatalog='cat /var/log/cloud-init-output.log'" >> /home/ubuntu/.bashrc
echo "alias p='pm2'" >> /home/ubuntu/.bashrc
echo "alias ps='pm2 status'" >> /home/ubuntu/.bashrc
echo "alias psreset='pm2 delete propintel'" >> /home/ubuntu/.bashrc
echo "alias out='sudo cat /home/ubuntu/.pm2/logs/front.mmi-out.log'" >> /home/ubuntu/.bashrc
echo "alias error='sudo cat /home/ubuntu/.pm2/logs/front-mmi-error.log'" >> /home/ubuntu/.bashrc
echo "alias listssh='cat /var/log/sshd.log'" >> /home/ubuntu/.bashrc
echo "alias p='pm2'" >> /home/ubuntu/.bashrc
echo "alias ..='cd ..'" >> /home/ubuntu/.bashrc
echo "alias c='clear'" >> /home/ubuntu/.bashrc
echo "alias ls='ls -la --color=auto'" >> /home/ubuntu/.bashrc
echo "alias ll='ls -la --color=auto'" >> /home/ubuntu/.bashrc
echo "alias countFiles='ls -1 | wc -l'" >> /home/ubuntu/.bashrc
sudo echo "alias available='sudo ls -al --color /etc/nginx/sites-available'" >> /home/ubuntu/.bashrc
sudo echo "alias ngx='cd /etc/nginx/sites-available/'" >> /home/ubuntu/.bashrc
sudo echo "alias rbash='source /home/ubuntu/.bashrc'" >> /home/ubuntu/.bashrc
sudo echo "alias ngxs='sudo systemctl status nginx'" >> /home/ubuntu/.bashrc
sudo echo "alias ngxstart='sudo systemctl start nginx'" >> /home/ubuntu/.bashrc
sudo echo "alias ngxreload='sudo systemctl reload nginx'" >> /home/ubuntu/.bashrc
sudo echo "alias ngxrestart='sudo systemctl restart nginx'" >> /home/ubuntu/.bashrc
sudo echo "alias nginxreload='sudo /usr/local/nginx/sbin/nginx -s reload'" >> /home/ubuntu/.bashrc
sudo echo "alias nginxtest='sudo /usr/local/nginx/sbin/nginx -t'" >> /home/ubuntu/.bashrc
echo '
fetch_public_ip() {
   curl -s http://icanhazip.com
}
if [ "$TERM" != "dumb" ]; then
   PROMPT_COMMAND='"'"'PS1_IP=$(fetch_public_ip); PS1_PATH=$(pwd)'"'"'
   PS1='"'"'FRONT.MMI.RUN [PROD] \[\e[91;1m\]\u\[\e[0m\]@:\[\e[93;1m\]${PS1_IP} \[\e[38;5;46m\]${PS1_PATH} \[\e[0;91m\]\\$\[\e[0m\] \[\e[0m\]'"'"'
fi
' >> /home/ubuntu/.bashrc
echo '
alias deploycheck='"'"'pm2 list && command -v nvm && node -v && aws --version && rustc --version && cargo --version && sudo systemctl status ssh && sudo systemctl status nginx && sudo nginx -t && pm2 info front.mmi && ls -l /home/ubuntu/ && ls -l /var/www/ && timedatectl && cat /var/log/cloud-init-output.log'"'"'
' >> /home/ubuntu/.bashrc
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/yarn-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/yarn-archive-keyring.gpg] https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs yarn
sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git curl wget zip openssh-server
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y awscli
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb
sudo systemctl enable ssh
sudo systemctl start ssh
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")" [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 18.18.2
nvm use 18.18.2
nvm alias default 18.18.2
npm install -g yarn pm2
curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx

create_server_block_and_landing_page() {
    local domain="$1"
    local doc_root="$2"
    local port="$3"
    sudo mkdir -p "$doc_root"
    cat <<EOF | sudo tee "/etc/nginx/sites-available/$domain"
server {
    listen 80;
    listen [::]:80;
    server_name $domain;
    root $doc_root;
    index index.html index.htm index.nginx-debian.html;
    location / {
        proxy_pass http://127.0.0.1:$port;
        proxy_read_timeout 60;
        proxy_connect_timeout 60;
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
    location /_next/static {
        add_header Cache-Control "public, max-age=3600, immutable";
        proxy_pass http://127.0.0.1:$port/_next/static;
    }
}
EOF
    if [ ! -L "/etc/nginx/sites-enabled/$domain" ]; then
        sudo ln -s "/etc/nginx/sites-available/$domain" "/etc/nginx/sites-enabled/"
    fi
}

declare -A domains=( ["front.mmi.run"]="/var/www/html/front.mmi.run/current:3000" )

for domain in "${!domains[@]}"; do
    IFS=':' read -r doc_root port <<< "${domains[$domain]}"
    create_server_block_and_landing_page "$domain" "$doc_root" "$port"
done

sudo systemctl reload nginx

app_root="/var/www/html/front.mmi.run/current"

setup_and_start_app() {
    local app_root="$1"
    local app_name="$2"
    local pm2_command="$3"
    cd "$app_root"
    yarn install
    if pm2 show "$app_name" > /dev/null 2>&1; then
        pm2 restart "$app_name" --update-env
    else
        eval "$pm2_command"
    fi
}

setup_and_start_app "$app_root" "front.mmi" "pm2 start yarn --interpreter bash --name \"front.mmi\" --watch -- start"
sudo timedatectl set-timezone America/Denver
sudo chown ubuntu:ubuntu /home/ubuntu/.bashrc
sudo chown ubuntu:ubuntu /home/ubuntu/.bash_aliases
sudo chown -R ubuntu:ubuntu /home/ubuntu/ /var/www/
sudo chmod -R 755 /home/ubuntu/ /var/www/
pm2 save
pm2 reload all
