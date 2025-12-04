
# **Three-Tier AWS Architecture – Terraform Project**

## **📝 Overview**

This project deploys a **highly available, secure, and scalable 3-Tier Architecture on AWS** using Terraform.
The architecture includes:

* **Presentation Tier (Public Subnet)** → NGINX (React static hosting)
* **Application Tier (Private Subnet)** → Node.js + PM2
* **Data Tier (Private Subnet)** → Amazon RDS (MySQL)
* Multi-AZ deployment across **Availability Zone A & B**
* Layer-7 load balancing using **Application Load Balancer (ALB)**
* HTTPS termination with SSL

This README explains the components, flow, and Terraform structure.

---

# **📌 Architecture Diagram**

*(Add your architecture image here)*
`![Architecture](three-tier-architecture-1.png)`

---

# **🏗 Architecture Components**

## **1️⃣ VPC Layer**

The VPC contains the full application stack and follows AWS best practices:

* **VPC**
* **Public Subnets (AZ-A, AZ-B)** → Nginx servers
* **Private Subnets (AZ-A, AZ-B)** → Node.js/PM2 + RDS
* **Internet Gateway**
* **NAT Gateway** (for private subnet outbound access)

---

## **2️⃣ Presentation Tier (NGINX – Public Subnet)**

* Hosted on EC2 inside **public subnets**
* NGINX serves:

  * React UI files
  * Acts as a reverse proxy to Node.js backend
* Traffic routed via **ALB → NGINX**

---

## **3️⃣ Application Tier (Node.js + PM2 – Private Subnet)**

* Node.js backend runs on EC2 inside **private subnets**
* **PM2** ensures:

  * Process monitoring
  * Auto-restart on crash
* Only accessible from **NGINX security group**
* No direct internet access

---

## **4️⃣ Data Tier (Amazon RDS – MySQL)**

* RDS deployed in **private DB subnets**
* Multi-AZ setup for high availability
* Accessible only from Application Tier SG
* Not accessible from the internet

---

## **5️⃣ Load Balancing + SSL**

* **Application Load Balancer (ALB)** distributes traffic to NGINX EC2s
* HTTPS enabled with:

  * **ACM SSL Certificate**
  * **Route53 domain mapping (optional)**

---

# **🔐 Security Design**

| Layer              | Security                                  |
| ------------------ | ----------------------------------------- |
| **Public Subnet**  | Only ALB + NGINX exposed to internet      |
| **Private Subnet** | Node.js app accessible only from NGINX SG |
| **DB Subnet**      | MySQL accessible only from Application SG |
| **No public IPs**  | For backend + DB tiers                    |
| **NAT Gateway**    | Safe outbound internet access             |

---

# **🔁 Request Flow**

1. User accesses **[https://yourdomain.com](https://yourdomain.com)**
2. Route53 → ALB
3. ALB routes to **NGINX (Public Subnet)**
4. NGINX serves UI and forwards API requests to **Node.js (Private Subnet)**
5. Node.js connects to **RDS MySQL**
6. Response goes back through same path

---

# **🧱 Terraform Structure**

Recommended folder layout:

```
terraform-project/
│
├── modules/
│   ├── vpc/
│   ├── alb/
│   ├── ec2-nginx/
│   ├── ec2-node/
│   ├── rds/
│   └── security-groups/
│
├── envs/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── README.md
```

---

# **🚀 Deployment Steps**

## **1. Initialize Terraform**

```
terraform init
```

## **2. Validate the configuration**

```
terraform validate
```

## **3. Preview changes**

```
terraform plan
```

## **4. Deploy**

```
terraform apply
```

## **5. Destroy environment**

```
terraform destroy
```

---

# **⚙ Technologies Used**

* **Terraform**
* **AWS VPC, EC2, ALB, RDS, Route53, ACM**
* **NGINX**
* **Node.js + PM2**
* **MySQL**

---

# **📦 Features**

* Multi-AZ High Availability
* Secure Public + Private Subnet Architecture
* Automated backend and frontend deployment
* Backend process manager (PM2)
* Encrypted database connections
* Scalable ALB front-end

---

# **📄 License**

This project is licensed under your organization or personal terms.

