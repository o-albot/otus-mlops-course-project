.PHONY: help init plan apply destroy clean kubeconfig status check-nodes generate-secret save-outputs

help:
	@echo "Commands:"
	@echo "  make init          - Terraform init"
	@echo "  make plan          - Terraform plan"
	@echo "  make apply         - Create infrastructure"
	@echo "  make destroy       - Destroy infrastructure"
	@echo "  make clean         - Clean Terraform cache"
	@echo "  make kubeconfig    - Update kubeconfig"
	@echo "  make check-nodes   - Check cluster nodes"
	@echo "  make status        - Show infrastructure status"
	@echo "  make generate-secret - Generate s3-secret.yaml"

init:
	cd infra && terraform init

plan: init
	cd infra && terraform plan

apply: init
	cd infra && terraform apply -auto-approve
	cd infra && terraform output
	$(MAKE) save-outputs
	$(MAKE) generate-secret
	$(MAKE) kubeconfig
	$(MAKE) check-nodes

destroy: init
	cd infra && terraform destroy -auto-approve

clean:
	rm -rf infra/.terraform infra/.terraform.lock.hcl infra/terraform.tfvars
	rm -f k8s/s3-secret.yaml

save-outputs:
	@echo "Saving outputs to .env..."
	@cd infra && \
	sed -i '/^BUCKET_NAME=/d' ../.env 2>/dev/null || true; \
	sed -i '/^CLUSTER_ID=/d' ../.env 2>/dev/null || true; \
	sed -i '/^CLUSTER_NAME=/d' ../.env 2>/dev/null || true; \
	echo "BUCKET_NAME=$$(terraform output -raw bucket_name 2>/dev/null)" >> ../.env; \
	echo "CLUSTER_ID=$$(terraform output -raw cluster_id 2>/dev/null)" >> ../.env; \
	echo "CLUSTER_NAME=$$(terraform output -raw cluster_name 2>/dev/null)" >> ../.env
	@echo "Outputs saved to .env"

generate-secret:
	@echo "Generating k8s/s3-secret.yaml..."
	@if [ -f .env ]; then \
		. ./.env; \
		export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY BUCKET_NAME; \
		envsubst < k8s/s3-secret.template.yaml > k8s/s3-secret.yaml; \
		echo "✅ k8s/s3-secret.yaml generated"; \
	else \
		echo "❌ .env file not found"; \
	fi

kubeconfig:
	@CLUSTER_ID=$$(grep '^CLUSTER_ID=' .env | cut -d= -f2 | tr -d ' '); \
	if [ -n "$$CLUSTER_ID" ]; then \
		yc managed-kubernetes cluster get-credentials $$CLUSTER_ID --external --force; \
	else \
		echo "CLUSTER_ID not found in .env"; \
	fi

check-nodes:
	kubectl get nodes -o wide

status:
	@if [ -f .env ]; then \
		echo "Project: $$(grep '^PROJECT_NAME=' .env | cut -d= -f2)"; \
		echo "Bucket: $$(grep '^BUCKET_NAME=' .env | cut -d= -f2)"; \
		echo "Cluster: $$(grep '^CLUSTER_NAME=' .env | cut -d= -f2)"; \
		echo "Cluster ID: $$(grep '^CLUSTER_ID=' .env | cut -d= -f2)"; \
	else \
		echo "No .env file found"; \
	fi
