.PHONY: local tf-init tf-plan tf-apply tf-destroy help

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

local: ## Run the application locally using Docker Compose
	docker-compose up --build

tf-init: ## Initialize Terraform providers
	cd terraform && terraform init

tf-plan: ## Preview Terraform infrastructure changes
	cd terraform && terraform plan

tf-apply: ## Apply Terraform infrastructure to AWS
	cd terraform && terraform apply

tf-destroy: ## Destroy all AWS infrastructure (Cost $0)
	cd terraform && terraform destroy
