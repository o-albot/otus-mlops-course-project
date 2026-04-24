#!/bin/bash

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Generating variables.json from Terraform outputs and K8s services...${NC}"

# Перейти в директорию infra для получения outputs
cd infra || exit 1

# Получить значения из Terraform outputs
YC_ZONE=$(terraform output -raw yc_zone 2>/dev/null)
YC_FOLDER_ID=$(terraform output -raw yc_folder_id 2>/dev/null)
YC_SUBNET_ID=$(terraform output -raw subnet_id 2>/dev/null)
DP_SA_ID=$(terraform output -raw dp_service_account_id 2>/dev/null)
DP_SA_AUTH_KEY_PUBLIC_KEY=$(terraform output -raw dp_public_ssh_key 2>/dev/null)
DP_SECURITY_GROUP_ID=$(terraform output -raw dp_security_group_id 2>/dev/null)

# Получить JSON как строку (сохраняя формат)
DP_SA_JSON=$(terraform output -json dp_service_account_json 2>/dev/null)

# Вернуться в корень проекта
cd ..

# Получить YC_SSH_PUBLIC_KEY
if [ -f ~/.ssh/id_rsa.pub ]; then
    YC_SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)
else
    echo -e "${YELLOW}Warning: ~/.ssh/id_rsa.pub not found. Using placeholder.${NC}"
    YC_SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC..."
fi

# Получить MLFLOW_TRACKING_URI
echo -e "${YELLOW}Waiting for MLflow service to be ready...${NC}"
MLFLOW_IP=""
for i in {1..30}; do
    MLFLOW_IP=$(kubectl get svc -n mlops mlflow -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$MLFLOW_IP" ] && [ "$MLFLOW_IP" != "<pending>" ]; then
        break
    fi
    echo -n "."
    sleep 5
done

if [ -z "$MLFLOW_IP" ] || [ "$MLFLOW_IP" = "<pending>" ]; then
    echo -e "${YELLOW}Warning: Could not get MLflow external IP. Using internal service name.${NC}"
    MLFLOW_TRACKING_URI="http://mlflow-service.mlops:5000"
else
    MLFLOW_TRACKING_URI="http://${MLFLOW_IP}:5000"
fi

echo -e "${GREEN}MLflow tracking URI: ${MLFLOW_TRACKING_URI}${NC}"

# Проверка обязательных переменных
if [ -z "$DP_SA_JSON" ] || [ "$DP_SA_JSON" = "null" ]; then
    echo -e "${RED}Error: DP_SA_JSON is empty. Make sure terraform output exists.${NC}"
    exit 1
fi

# Создание variables.json (правильный JSON формат)
cat > variables.json << EOF
{
  "YC_ZONE": "${YC_ZONE}",
  "YC_FOLDER_ID": "${YC_FOLDER_ID}",
  "YC_SUBNET_ID": "${YC_SUBNET_ID}",
  "YC_SSH_PUBLIC_KEY": "${YC_SSH_PUBLIC_KEY}",
  "DP_SA_ID": "${DP_SA_ID}",
  "DP_SA_AUTH_KEY_PUBLIC_KEY": "${DP_SA_AUTH_KEY_PUBLIC_KEY}",
  "DP_SA_JSON": ${DP_SA_JSON},
  "DP_SECURITY_GROUP_ID": "${DP_SECURITY_GROUP_ID}",
  "MLFLOW_TRACKING_URI": "${MLFLOW_TRACKING_URI}"
}
EOF

# Проверить, что файл валидный
if command -v jq &> /dev/null; then
    if jq empty variables.json 2>/dev/null; then
        echo -e "${GREEN}variables.json created successfully! (valid JSON)${NC}"
    else
        echo -e "${RED}Error: Generated variables.json is not valid JSON${NC}"
        cat variables.json
        exit 1
    fi
else
    echo -e "${GREEN}variables.json created successfully!${NC}"
fi

echo -e "${YELLOW}File content preview:${NC}"
head -15 variables.json