### How to deploy docker-registry

1. Copy the content of this folder to a folder anywhere in your local machine
2. Terraform.tfvars.template > terraform.tfvars and fill the variables
    - You can use export TF_VAR_<variable_name>=<value> to set the sensitive variables
3. Open the terminal and navigate to the folder
4. Source openstack credentials
5. Start ssh agent by `eval $(ssh-agent)`
6. Add your ssh key to the agent by `ssh-add <path/to/key>`
7. Run the command `terraform init` to initialize the terraform environment
8. Run the command `terraform plan` to see the execution plan
5. Run the command `terraform apply` to apply the changes
6. Run the command `terraform destroy` to destroy the infrastructure
