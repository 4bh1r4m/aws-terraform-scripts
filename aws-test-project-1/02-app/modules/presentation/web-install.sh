#!/bin/bash

# INSTALL SYSTEM DEPENDENCIES
dnf update -y
dnf install git nginx -y

# Enable and start Nginx immediately so we can confirm instance is alive
systemctl enable nginx
systemctl start nginx

# We switch to ec2-user for the build process to avoid permission issues later
su - ec2-user -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
su - ec2-user -c '. ~/.nvm/nvm.sh && nvm install --lts'

# CLONE & CONFIGURE FRONTEND
su - ec2-user -c 'git clone https://github.com/Learn-It-Right-Way/lirw-react-node-mysql-app.git ~/lirw-react-node-mysql-app'

# Create the .env file for the build
# We set the API URL to "/api" so the browser sends requests to Nginx (which proxies them)
su - ec2-user -c 'echo "VITE_API_URL=/api" > ~/lirw-react-node-mysql-app/frontend/.env'

# BUILD REACT APP
su - ec2-user -c '
    . ~/.nvm/nvm.sh
    cd ~/lirw-react-node-mysql-app/frontend
    npm install
    npm run build
'

#DEPLOY TO NGINX
# Create the directory structure
mkdir -p /usr/share/nginx/html/dist

# Copy the build artifacts from the user home to the web root
cp -r /home/ec2-user/lirw-react-node-mysql-app/frontend/dist/* /usr/share/nginx/html/dist/

# Fix permissions so Nginx can read the files
chown -R nginx:nginx /usr/share/nginx/html/dist
chmod -R 755 /usr/share/nginx/html/dist

#CONFIGURE NGINX (Reverse Proxy)
# We overwrite the default server block.
# Terraform replaces ${app_tier_ip} with the private IP of the specific App Tier instance.

cat <<EOF > /etc/nginx/conf.d/pointbreak.conf
server {
    listen 80;
    server_name pointbreak.space www.pointbreak.space;

    root /usr/share/nginx/html/dist;
    index index.html;

    # Serve the React App (Single Page Application support)
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Reverse Proxy for API calls
    # Forwards /api/users -> http://10.0.x.x:3200/api/users
    location /api {
        proxy_pass http://${app_tier_ip}:3200;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Disable the default Nginx welcome page config to avoid conflicts
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
# Write a minimal standard nginx.conf that includes our custom conf.d files
cat <<EOF > /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;
    sendfile on;
    keepalive_timeout 65;
    
    # Load our custom config from above
    include /etc/nginx/conf.d/*.conf;
}
EOF

#ADD SSH KEY (From your previous setup)
cat <<'KEY_FILE'> /home/ec2-user/private_key.pem
${ssh_private_key}
KEY_FILE
chown ec2-user:ec2-user /home/ec2-user/private_key.pem
chmod 400 /home/ec2-user/private_key.pem

# Test Nginx configuration and restart to apply changes
nginx -t
systemctl restart nginx