# Fuego Socks - AWS EKS Microservices Demo Infrastructure

This project demonstrates provisioning AWS infrastructure using **AWS CloudFormation** to deploy a scalable e-commerce microservices application on **AWS EKS**. 
The deployment leverages CloudFormation templates for infrastructure as code, **Helm charts** for application packaging, and kubectl for **Kubernetes** resource management.

---

![Sock Shop Frontend](https://raw.githubusercontent.com/microservices-demo/microservices-demo.github.io/master/assets/sockshop-frontend.png)


---

## Project Structure

```
.
├── parameters
│   ├── dev.json           # Parameter overrides for dev environment
│   └── prod.json          # Parameter overrides for prod environment
├── scripts
│   ├── dev         # Scripts to provision infra, deploy Helm charts, and expose app
│   └── prod      
└── templates
    ├── compute           # template for compute resources (EKS cluster, node groups)
    ├── network           # template for VPC, subnets, routing, gateways
    ├── root-stack.yaml   # Root CloudFormation stack referencing nested stacks
    ├── observability     # template for cloudwatch dashboard and alarms
    └── security          # template for IAM roles, policies, and security groups
```

---

## Prerequisites

- AWS CLI configured with permissions to create CloudFormation stacks, IAM roles, and EKS resources  
- `kubectl` installed and configured  
- `helm` installed  
- `eksctl` installed (used in deploy script for IAM service account creation)  

---

## 1. Infrastructure Deployment

1. **Update variables** in `scripts/deploy.sh` as needed (region, cluster name, etc.).  
2. **Run the deployment script:**

```bash
chmod +x scripts/dev/deploy.sh
./scripts/dev/deploy.sh
```

This script will:

- Create or verify your S3 bucket for CloudFormation templates  
- Package and deploy CloudFormation stacks for networking, compute, and security   
- Create and setup EKS Cluster with Managed Node Workers 

---


## 2. Microservice Deployment

1. **Update variables** in `scripts/microservice-deploy.sh` as needed.  
2. **Run the deployment script:**

```bash
chmod +x scripts/dev/microservice-deploy.sh
./scripts/dev/microservice-deploy.sh
```

This script will:

- Verify that aws, kubectl, and helm are installed
- Updates local kubeconfig 
- Install the AWS Load Balancer Controller via Helm
- Deploy the Bitnami microservices demo Helm chart (Sock Shop)  
- Apply the Kubernetes Ingress resource to expose the app externally  

---

## 3. Accessing the Application

After deployment:

1. Run:

```bash
kubectl get ingress microservices-demo-ingress
```

2. Note the **ADDRESS** field — this is the DNS name of the AWS Application Load Balancer.  
3. Open the DNS URL in your browser to access the Sock Shop demo application.

---

## Customization

- Adjust CloudFormation templates in the `templates/` directory to fit your networking and compute requirements.  
- Modify Helm chart values or switch to your own Helm charts in the deployment script.  
- Update `parameters/dev.json` and `parameters/prod.json` for environment-specific settings.

---

## License

This project is licensed under the MIT License.

---

## Acknowledgments

- [Bitnami Microservices Demo Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/microservices-demo)  
- [AWS Load Balancer Controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller)  
- AWS and Kubernetes communities for excellent documentation and tools.

---

Feel free to open issues or pull requests to improve this project!
