.PHONY: help init plan apply destroy clean kubeconfig status

help:
	@echo "Available commands:"
	@echo "  make init       - Initialize Terraform"
	@echo "  make plan       - Show infrastructure plan"
	@echo "  make apply      - Create infrastructure"
	@echo "  make destroy    - Destroy infrastructure"
	@echo "  make clean      - Clean Terraform cache"
	@echo "  make kubeconfig - Update kubeconfig"
	@echo "  make status     - Show infrastructure status"

init:
	cd infra && terraform init

plan: init
	cd infra && terraform plan

apply: init
	cd infra && terraform apply -auto-approve
	@echo "Infrastructure created!"
	cd infra && terraform output

destroy: init
	cd infra && terraform destroy -auto-approve

clean:
	rm -rf infra/.terraform infra/.terraform.lock.hcl infra/terraform.tfvars

kubeconfig:
	@if [ -n "$$CLUSTER_ID" ]; then \
		yc managed-kubernetes cluster get-credentials $$CLUSTER_ID --external --force; \
	else \
		echo "CLUSTER_ID not set. Run 'make apply' first."; \
	fi

status:
	@if [ -f .env ]; then \
		echo "Project: $$(grep PROJECT_NAME .env | cut -d= -f2)"; \
		echo "Bucket: $$(grep BUCKET_NAME .env | cut -d= -f2)"; \
		echo "Cluster: $$(grep CLUSTER_NAME .env | cut -d= -f2)"; \
	else \
		echo "No .env file found. Run 'make apply' first."; \
	fi
