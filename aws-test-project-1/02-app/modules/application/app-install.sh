#!/bin/bash

#1. SYSTEM PREPARATION & DEPENDENCIES
#Update system packages
dnf update -y
dnf install git -y

#install Node.js (LTS) for ec2-user
su - ec2-user -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
su - ec2-user -c '. ~/.nvm/nvm.sh && nvm install --lts'


#2. CLONE REPOSITORY
su - ec2-user -c 'git clone https://github.com/Learn-It-Right-Way/lirw-react-node-mysql-app.git ~/lirw-react-node-mysql-app'


#3. DATABASE INITIALIZATION (CONDITIONAL)
#block runs ONLY if Terraform sets run_db_init="true"
if [ "${run_db_init}" = "true" ]; 
then
    echo "This is the primary instance. Starting Database Initialization..."

    # Install MariaDB Client (needed to run the mysql command)
    dnf install mariadb105 -y

    # Create the SQL setup file dynamically
    # Note: We escape backticks (\`) so bash doesn't try to execute them
    cat <<EOF > /home/ec2-user/db_setup.sql
-- Create Database and User safely
CREATE DATABASE IF NOT EXISTS ${db_name};

-- Create the App User (if not exists) and grant permissions
CREATE USER IF NOT EXISTS '${db_username}'@'%' IDENTIFIED BY '${db_password}';
GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_username}'@'%';
FLUSH PRIVILEGES;

USE ${db_name};

-- Create Table: Author
CREATE TABLE IF NOT EXISTS \`author\` (
  \`id\` int NOT NULL AUTO_INCREMENT,
  \`name\` varchar(255) NOT NULL,
  \`birthday\` date NOT NULL,
  \`bio\` text NOT NULL,
  \`createdAt\` date NOT NULL,
  \`updatedAt\` date NOT NULL,
  PRIMARY KEY (\`id\`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Create Table: Book
CREATE TABLE IF NOT EXISTS \`book\` (
  \`id\` int NOT NULL AUTO_INCREMENT,
  \`title\` varchar(255) NOT NULL,
  \`releaseDate\` date NOT NULL,
  \`description\` text NOT NULL,
  \`pages\` int NOT NULL,
  \`createdAt\` date NOT NULL,
  \`updatedAt\` date NOT NULL,
  \`authorId\` int DEFAULT NULL,
  PRIMARY KEY (\`id\`),
  KEY \`FK_author\` (\`authorId\`),
  CONSTRAINT \`FK_author\` FOREIGN KEY (\`authorId\`) REFERENCES \`author\` (\`id\`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Insert Data: Authors (Using INSERT IGNORE to prevent duplicates on re-runs)
INSERT IGNORE INTO \`author\` VALUES 
(1,'J.K. Rowling (Joanne Kathleen Rowling)','1965-07-31','J.K. Rowling is a British author best known for writing the Harry Potter fantasy series...','2024-05-29','2024-05-29'),
(3,'Jane Austen','1775-12-16','Jane Austen was an English novelist known for her wit...','2024-05-29','2024-05-29'),
(4,'Harper Lee','1960-07-11','Harper Lee was an American novelist best known for...','2024-05-29','2024-05-29'),
(5,'J.R.R. Tolkien','1954-07-29','J.R.R. Tolkien was a British philologist...','2024-05-29','2024-05-29'),
(6,'Mary Shelley','1818-03-03','Mary Shelley was a British novelist...','2024-05-29','2024-05-29'),
(7,'Douglas Adams','1979-10-12','Douglas Adams was an English science fiction writer...','2024-05-29','2024-05-29');

-- Insert Data: Books
INSERT IGNORE INTO \`book\` VALUES 
(1,'Harry Potter and the Sorcerer\'s Stone','1997-07-26','On his birthday, Harry Potter discovers...','223','2024-05-29','2024-05-29',1),
(3,'Harry Potter and the chamber of secrets','1998-07-02','Harry Potter and the sophomores investigate...','251','2024-05-29','2024-05-29',1),
(4,'Pride and Prejudice','1813-01-28','An English novel of manners...','224','2024-05-29','2024-05-29',3),
(5,'Harry Potter and the Prisoner of Azkaban','1999-07-08','Harry\'s third year...','317','2024-05-29','2024-05-29',1),
(6,'Harry Potter and the Goblet of Fire','2000-07-08','Hogwarts prepares...','636','2024-05-29','2024-05-29',1),
(7,'The Hitchhiker\'s Guide to the Galaxy','1979-10-12','A comic science fiction comedy...','184','2024-05-29','2024-05-29',7),
(8,'Frankenstein; or, The Modern Prometheus','1818-03-03','A Gothic novel...','211','2024-05-29','2024-05-29',6),
(9,'The Lord of the Rings: The Fellowship of the Ring','1954-07-29','The first book...','482','2024-05-29','2024-05-29',5);
EOF

    #Execute the SQL script using the MASTER credentials passed from Terraform
    echo "Executing SQL setup..."
    mysql -h ${rds_endpoint} -u ${db_master_user} -p"${db_master_password}" < /home/ec2-user/db_setup.sql
    echo "Database Initialization Complete."
fi

#4. CONFIGURE APPLICATION (db.js)
#write the db.js file using the APP USER credentials
cat <<EOF > /home/ec2-user/lirw-react-node-mysql-app/backend/configs/db.js
const mysql = require('mysql2');

const db = mysql.createConnection({
   host: '${rds_endpoint}',
   port: '3306',
   user: '${db_username}',
   password: '${db_password}',
   database: '${db_name}'
});

module.exports = db;
EOF

#ensure ec2-user owns the config file
chown ec2-user:ec2-user /home/ec2-user/lirw-react-node-mysql-app/backend/configs/db.js

# 
#5. START APPLICATION
su - ec2-user -c '
    . ~/.nvm/nvm.sh
    cd ~/lirw-react-node-mysql-app/backend
    npm install
    npm audit fix
    npm install pm2 -g
    # npm run serve
    pm2 logs server
    # Start the application
    pm2 start server.js --name "api-server"
    pm2 save
    pm2 startup systemd -u ec2-user --hp /home/ec2-user
'

# ====================================================
# 6. CREATE TROUBLESHOOTING HELPER SCRIPT
# We create a handy script for future debugging
cat <<EOF > /home/ec2-user/fix_app.sh
#!/bin/bash
# Troubleshooting script for App Tier
echo "Stopping all PM2 processes..."
pm2 delete all

echo "Starting server.js..."
cd ~/lirw-react-node-mysql-app/backend
pm2 start server.js --name "api-server"

echo "Saving PM2 list..."
pm2 save

echo "Verifying connection..."
curl http://localhost:3200/api/books
EOF

# Make it executable and owned by ec2-user
chmod +x /home/ec2-user/fix_app.sh
chown ec2-user:ec2-user /home/ec2-user/fix_app.sh