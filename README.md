# project-static-site-azure

📖 Project Overview

This project demonstrates the complete process of deploying a static website onto Microsoft Azure using Azure CLI and Bash scripting.

The objective is to fully automate the provisioning of cloud infrastructure, configuration of a web server (NGINX), and deployment of static web content.
Additionally, a CI/CD pipeline is implemented via GitHub Actions to ensure automated and repeatable deployments.

🎯 Project Objectives

Automate the creation of Azure cloud infrastructure (Resource Group, VNet, Subnets, NSG, and VM).

Deploy a Linux VM (Ubuntu) to host a static website served by NGINX.

Configure Network Security Groups (NSGs) for secure web traffic (HTTP/HTTPS).

Store all scripts in GitHub following best version-control practices.

Implement a GitHub Actions workflow for continuous deployment.

Provide complete documentation, screenshots, and presentation materials.

### Architecture Diagram

```
 GitHub Repo (Scripts + CI/CD)
          │
          ▼
   GitHub Actions Workflow
          │
          ▼
 ┌──────────────────────────────┐
 │     Azure Cloud Platform     │
 │ ┌──────────────────────────┐ │
 │ │  Resource Group (RG)     │ │
 │ │ ┌──────────────────────┐ │ │
 │ │ │  Virtual Network     │ │ │
 │ │ │   ├─ Subnet          │ │ │
 │ │ │   ├─ NSG (Ports 22/80/443) │
 │ │ │   └─ Linux VM (NGINX) │ │ │
 │ │ └──────────────────────┘ │ │
 │ └──────────────────────────┘ │
 └──────────────────────────────┘
          │
          ▼
     🌍 Public IP (Live Website)
```

---

## ⚙️ Project Structure

```
├── infra/
│   ├── create_infra.sh
│   ├── destroy_infra.sh
│   └── config_nsg.sh
│
├── vm/
│   ├── deploy_vm.sh
│   ├── install_nginx.sh
│   └── deploy_site.sh
│
├── site/
│   ├── index.html
│   ├── style.css
│   └── assets/
│
├── .github/
│   └── workflows/
│       └── deploy.yml
│
├── screenshots/
│   ├── step1_resource_group.png
│   ├── step2_vnet_nsg.png
│   ├── step3_vm_overview.png
│   ├── step4_nginx_running.png
│   ├── step5_live_site.png
│
└── README.md
```

---

🧱 Architecture Overview
Architecture Components

| Component                        | Description                                           |
| -------------------------------- | ----------------------------------------------------- |
| **Resource Group**               | Container for all deployed resources                  |
| **Virtual Network (VNet)**       | Logical isolation of Azure network                    |
| **Subnet**                       | Subdivision of VNet for hosting the web server        |
| **Network Security Group (NSG)** | Controls inbound/outbound traffic (ports 22, 80, 443) |
| **Virtual Machine (Ubuntu)**     | Hosts the NGINX web server and static website         |
| **NGINX Web Server**             | Serves the static HTML website                        |
| **GitHub Actions**               | Automates the provisioning and deployment process     |

⚙️ Project Folder Structure

├── infra/
│ ├── create_infra.sh # Automates Azure resource creation
│ ├── destroy_infra.sh # Deletes all resources to avoid costs
│ └── config_nsg.sh # Configures inbound/outbound NSG rules
│
├── vm/
│ ├── deploy_vm.sh # Creates Ubuntu VM via CLI
│ ├── install_nginx.sh # Installs and configures NGINX
│ └── deploy_site.sh # Copies website files to /var/www/html
│
├── site/
│ ├── index.html # Main homepage for the static website
│ ├── style.css # Optional stylesheet
│ └── assets/ # Images, icons, etc.
│
├── .github/
│ └── workflows/
│ └── deploy.yml # GitHub Actions CI/CD workflow
│
├── screenshots/
│ ├── step1_resource_group.png
│ ├── step2_vnet_nsg.png
│ ├── step3_vm_overview.png
│ ├── step4_nginx_running.png
│ ├── step5_live_site.png
│ └── ...
│
└── README.md # Project documentation (this file)

💻 Automation Workflow

1️⃣ Create Infrastructure

The following command provisions all required Azure resources:

bash infra/create_infra.sh

This script:

1. Creates a resource group

2. Builds a VNet and subnet

3. Configures a Network Security Group (NSG) with rules for HTTP, HTTPS, and SSH

4. Deploys a Linux VM with a public IP

2️⃣ Deploy Linux VM and Install NGINX

1. Run the VM deployment script:

bash vm/deploy_vm.sh

2. Then install and start NGINX automatically:

bash vm/install_nginx.sh

3. Verify NGINX is running:

sudo systemctl status nginx

3️⃣ Upload and Deploy Website Files

Use the deployment script to copy the static files to the VM:

bash vm/deploy_site.sh

Files are uploaded to /var/www/html/ on the VM.

Access the website at:

http://<your_public_ip>/

4️⃣ Configure Network Rules

Ensure the NSG allows web traffic:

az network nsg rule create \
 --resource-group rg-blizzy-static \
 --nsg-name nsg-web \
 --name AllowHTTP \
 --protocol Tcp \
 --priority 1001 \
 --destination-port-ranges 80 \
 --access Allow

5️⃣ CI/CD with GitHub Actions

The deploy.yml workflow automates:

1. Azure CLI login (via service principal)

2. Infrastructure provisioning

3. VM deployment

4. Website deployment

Workflow triggers:

On every git push to main

On manual dispatch (workflow_dispatch)

name: Azure Static Website Deployment

on:
push:
branches: [ main ]
workflow_dispatch:

jobs:
deploy:
runs-on: ubuntu-latest
steps: - name: Checkout repo
uses: actions/checkout@v3

      - name: Azure CLI Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Run Infrastructure Script
        run: bash infra/create_infra.sh

      - name: Deploy VM and Install NGINX
        run: bash vm/deploy_vm.sh && bash vm/install_nginx.sh

      - name: Deploy Static Site
        run: bash vm/deploy_site.sh

6️⃣ Destroy Infrastructure (Cleanup)

To prevent charges, run:

bash infra/destroy_infra.sh

The above script deletes all resources within the resource group.

🌍 Live Website
Public IP:
http://<YOUR_PUBLIC_IP>/

Once deployed, this IP will render the custom static website hosted via NGINX on Azure.

📸 Screenshots

| Step | Screenshot               | Description                        |
| ---- | ------------------------ | ---------------------------------- |
| 1    | Resource Group Overview  | Shows created RG and all resources |
| 2    | Virtual Network + Subnet | Network setup                      |
| 3    | NSG Rules                | Ports 22, 80, 443 allowed          |
| 4    | VM Overview              | Linux VM running                   |
| 5    | NGINX Active             | Web server running                 |
| 6    | Live Website             | Browser view of hosted site        |
| 7    | GitHub Actions           | Successful CI/CD deployment        |

🧠 Key Learnings

1. Mastered Azure CLI automation for resource provisioning.

2. Deployed NGINX web servers on Ubuntu via script.

3. Implemented CI/CD pipelines using GitHub Actions.

4. Practiced version control and infrastructure reproducibility.

5. Gained deeper understanding of network security configurations.

⚡ Technologies Used

| Category        | Tools                     |
| --------------- | ------------------------- |
| Cloud Platform  | Microsoft Azure           |
| OS              | Ubuntu 22.04 LTS          |
| Web Server      | NGINX                     |
| Automation      | Bash Scripting, Azure CLI |
| CI/CD           | GitHub Actions            |
| Version Control | Git + GitHub              |
| Documentation   | Markdown + Screenshots    |

Tools and Technologies Used

| Tool                | Purpose                                 |
| ------------------- | --------------------------------------- |
| **Azure CLI**       | Infrastructure creation & configuration |
| **Bash Scripting**  | Automation of deployment commands       |
| **NGINX**           | Web server for serving static files     |
| **GitHub Actions**  | CI/CD for automatic deployment          |
| **Ubuntu LTS (VM)** | Hosting environment for website         |
| **SSH Keys**        | Secure access to VM                     |

🧩 Challenges & Solutions

| Challenge                                   | Solution                                                               |
| ------------------------------------------- | ---------------------------------------------------------------------- |
| Azure CLI authentication for GitHub Actions | Used `AZURE_CREDENTIALS` secret with service principal                 |
| NSG rule misconfiguration                   | Re-applied rule allowing inbound port 80                               |
| File permissions on NGINX root directory    | Updated ownership with `sudo chown -R www-data:www-data /var/www/html` |
| Pipeline timing errors                      | Added step delays and proper dependencies in workflow                  |

🧾 Deliverables

✅ Fully functional static website accessible via public IP
✅ Bash scripts for automation
✅ Complete GitHub repository
✅ CI/CD pipeline (GitHub Actions)
✅ Documentation and screenshots
✅ Presentation slide deck

📢 Conclusion

This project successfully demonstrates end-to-end cloud automation for static website hosting using Microsoft Azure.
It integrates Infrastructure as Code (IaC) principles with continuous deployment pipelines, resulting in a scalable, repeatable, and professional-grade cloud deployment workflow.

💡 “Automation turns manual deployment into a one-click experience.”
