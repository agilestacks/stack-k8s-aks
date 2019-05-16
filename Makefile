SHELL := /bin/bash
.DEFAULT_GOAL := deploy

DOMAIN_NAME    ?= superaks.azure.dev.superhub.io
COMPONENT_NAME ?= stack-k8s-aks

NAME           := $(shell echo $(DOMAIN_NAME) | cut -d. -f1)
BASE_DOMAIN    := $(shell echo $(DOMAIN_NAME) | cut -d. -f2-)

STATE_CONTAINER ?= agilestacks
STATE_BUCKET ?= azure.dev.superhub.io
STATE_REGION ?= not-used

export TF_VAR_client_id := $(ARM_CLIENT_ID)
export TF_VAR_client_secret := $(ARM_CLIENT_SECRET)

export TF_VAR_agent_count ?= 2
export TF_VAR_agent_vm_size ?= Standard_DS1_v2
export TF_VAR_agent_vm_os ?= Linux
export TF_VAR_resource_group_name ?= SuperHub
export TF_VAR_location ?= eastus
export TF_VAR_log_analytics_workspace_location ?= eastus
export TF_VAR_base_domain := $(BASE_DOMAIN)
export TF_VAR_cluster_name := $(CLUSTER_NAME)
export TF_VAR_name := $(NAME)

export TF_LOG      ?= info
export TF_DATA_DIR ?= .terraform/$(DOMAIN_NAME)
export TF_LOG_PATH ?= $(TF_DATA_DIR)/terraform.log
TF_CLI_ARGS := -no-color -input=false -lock=false
TFPLAN := $(TF_DATA_DIR)/$(DOMAIN_NAME).tfplan

terraform   ?= terraform-v0.11
az ?= az
kubectl ?= kubectl

deploy: init plan apply createsa token output

init:
	@mkdir -p $(TF_DATA_DIR)
	$(terraform) init -get=true $(TF_CLI_ARGS) -reconfigure -force-copy \
		-backend-config="storage_account_name=$${STATE_BUCKET//./}" \
		-backend-config="container_name=$(STATE_CONTAINER)" \
		-backend-config="resource_group_name=$(TF_VAR_resource_group_name)" \
		-backend-config="key=$(DOMAIN_NAME)/$(COMPONENT_NAME)/terraform.tfstate"
.PHONY: init

plan:
	$(terraform) plan $(TF_CLI_ARGS) \
	-var dns_prefix=$${DOMAIN_NAME//./} \
	-var log_analytics_workspace_name=$${DOMAIN_NAME//./}-ws \
	-refresh=true -module-depth=-1 -out=$(TFPLAN)
.PHONY: plan

apply:
	$(terraform) apply $(TF_CLI_ARGS) -Xshadow=false $(TFPLAN)
.PHONY: apply

context:
	$(az) aks get-credentials --resource-group $(TF_VAR_resource_group_name) --name $(TF_VAR_cluster_name)
.PHONY: context

createsa: context
	@if $(kubectl) get -n default serviceaccount $(SERVICE_ACCOUNT) ; then \
		echo "Service Account $(SERVICE_ACCOUNT) exists"; \
	else \
		$(kubectl) create -n default serviceaccount $(SERVICE_ACCOUNT); \
		$(kubectl) create clusterrolebinding $(SERVICE_ACCOUNT)-cluster-admin-binding \
			--clusterrole=cluster-admin --serviceaccount=default:$(SERVICE_ACCOUNT); \
	fi
	@sleep 10s
.PHONY: createsa

token:
	$(eval SECRET=$(shell $(kubectl) get serviceaccount $(SERVICE_ACCOUNT) -o json | \
		jq '.secrets[] | select(.name | contains("token")).name'))
	$(eval TOKEN_BASE64=$(shell $(kubectl) get secret $(SECRET) -o json | \
		jq '.data.token'))
	$(eval TOKEN=$(shell openssl enc -A -base64 -d <<< $(TOKEN_BASE64)))
.PHONY: token

output:
	@echo
	@echo Outputs:
	@echo dns_name = $(NAME)
	@echo dns_base_domain = $(BASE_DOMAIN)
	@echo token = $(TOKEN)
	@echo
.PHONY: output

destroy: TF_CLI_ARGS:=-destroy $(TF_CLI_ARGS)
destroy: plan

undeploy: init destroy apply
