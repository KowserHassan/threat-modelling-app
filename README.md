# Threat Modelling Tool 🛡️ 

This project leverages Amazon's open-source Threat Composer Tool to simplify threat modelling and security assessments using containerisation, Terraform for IaC and CI/CD automation to enhance deployment.

## **Purpose of the Threat Modelling Tool** 

- **Identify Potential Threats:** Understand and uncover security risks during the design and development stages of a system.
- **Visualise Vulnerabilities:** Create a clear picture of possible attack vectors and weak points in the software architecture.
- **Mitigate Risks Early:** Develop and implement strategies to reduce vulnerabilities before they can be exploited in production.

##  **Tech Stack** 🛠️

- **Infrastructure:** AWS (ECS, ECR, Route 53, ACM)
- **Containerisation:** Docker
- **Provisioning:** Terraform
- **CI/CD:** GitHub Actions
- **Languages:** Python 

## Local app setup 💻

```bash
yarn install
yarn build
yarn global add serve
serve -s build

#yarn start
http://localhost:3000/workspaces/default/dashboard

## or
yarn global add serve
serve -s build
```

## 🔗 **Useful Documentation**

- [Terraform AWS Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform AWS ECS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster)
- [Terraform Docs](https://www.terraform.io/docs/index.html)
- [ECS Docs](https://docs.aws.amazon.com/ecs/latest/userguide/what-is-ecs.html)
