.DEFAULT_GOAL := deploy

DOMAIN_NAME    ?= superaks.azure.dev.superhub.io
COMPONENT_NAME ?= stack-k8s-aks

NAME           := $(shell echo $(DOMAIN_NAME) | cut -d. -f1)
BASE_DOMAIN    := $(shell echo $(DOMAIN_NAME) | cut -d. -f2-)

STATE_ACCOUNT ?= viktors
STATE_CONTAINER   ?= terraformagilestacks

export TF_VAR_client_id := $(ARM_CLIENT_ID)
export TF_VAR_client_secret := $(ARM_CLIENT_SECRET)

export TF_VAR_agent_count ?= 2
export TF_VAR_resource_group_name ?= superhub
export TF_VAR_location ?= eastus
export TF_VAR_log_analytics_workspace_location ?= eastus
export TF_VAR_base_domain := $(BASE_DOMAIN)
export TF_VAR_name := $(NAME)

export TF_LOG      ?= info
export TF_DATA_DIR ?= .terraform/$(DOMAIN_NAME)
export TF_LOG_PATH ?= $(TF_DATA_DIR)/terraform.log
TF_CLI_ARGS := -no-color -input=false
TFPLAN := $(TF_DATA_DIR)/$(DOMAIN_NAME).tfplan

terraform   ?= terraform-v0.11

deploy: init plan apply

init:
	@mkdir -p $(TF_DATA_DIR)
	$(terraform) init -get=true $(TF_CLI_ARGS) -reconfigure -force-copy \
		-backend-config="storage_account_name=$(STATE_ACCOUNT)" \
		-backend-config="container_name=$(STATE_CONTAINER)" \
		-backend-config="access_key=$(STORAGE_ACCOUNT_KEY)" \
		-backend-config="key=$(DOMAIN_NAME)/$(COMPONENT_NAME)/terraform.tfstate"
.PHONY: init

plan:
	$(terraform) plan $(TF_CLI_ARGS) \
	-var dns_prefix=$${DOMAIN_NAME//./-} \
	-var cluster_name=$${DOMAIN_NAME//./-} \
	-var log_analytics_workspace_name=$${DOMAIN_NAME//./-}-ws \
	-refresh=true -module-depth=-1 -out=$(TFPLAN)
.PHONY: plan	

apply:
	$(terraform) apply $(TF_CLI_ARGS) -Xshadow=false $(TFPLAN)
.PHONY: apply

destroy: TF_CLI_ARGS:=-destroy $(TF_CLI_ARGS)
destroy: plan

undeploy: init destroy apply	
