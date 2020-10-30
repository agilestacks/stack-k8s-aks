.DEFAULT_GOAL := deploy

DOMAIN_NAME    ?= superaks.azure.superhub.io
COMPONENT_NAME ?= stack-k8s-aks

NAME           := $(shell echo $(DOMAIN_NAME) | cut -d. -f1)
BASE_DOMAIN    := $(shell echo $(DOMAIN_NAME) | cut -d. -f2-)
NAME2          := $(shell echo $(DOMAIN_NAME) | sed -E -e 's/[^[:alnum:]]+/-/g' | cut -c1-31 | sed -e 's/-$$//')

STATE_BUCKET ?= azuresuperhubio
STATE_CONTAINER ?= agilestacks

export TF_VAR_client_id := $(AZURE_CLIENT_ID)
export TF_VAR_client_secret := $(AZURE_CLIENT_SECRET)

export TF_VAR_agent_vm_size ?= Standard_DS1_v2
export TF_VAR_agent_vm_os ?= Linux
export TF_VAR_resource_group_name ?= SuperHub
export TF_VAR_location ?= eastus
export TF_VAR_base_domain := $(BASE_DOMAIN)
export TF_VAR_cluster_name := $(or $(CLUSTER_NAME),$(NAME2))
export TF_VAR_name := $(NAME)

az        ?= az
terraform ?= terraform-v0.12
kubectl   ?= kubectl

AKS_DEFAULT_VERSION = $(shell $(az) aks get-versions  --location $(TF_VAR_location) | \
	jq -r '.orchestrators[] | select(.default == true) | .orchestratorVersion')
export TF_VAR_k8s_version := $(or $(AKS_VERSION),$(AKS_DEFAULT_VERSION))

# create spot node pool if price is set and at least 2 workers; one worker must be in default node pool
WORKER_IMPL := $(if $(and $(TF_VAR_spot_agent_price),$(shell test $(AGENT_COUNT) -gt 1 && echo true)),spot,ondemand)
ifeq (spot,$(WORKER_IMPL))
export TF_VAR_agent_count := 1
export TF_VAR_spot_agent_count := $(shell expr $(AGENT_COUNT) - 1)
else
export TF_VAR_agent_count := $(AGENT_COUNT)
endif

export TF_DATA_DIR ?= .terraform/$(DOMAIN_NAME)
export TF_LOG_PATH ?= $(TF_DATA_DIR)/terraform.log

TF_CLI_ARGS := -input=false
TFPLAN      := $(TF_DATA_DIR)/$(DOMAIN_NAME).tfplan

export ARM_CLIENT_ID       ?= $(AZURE_CLIENT_ID)
export ARM_CLIENT_SECRET   ?= $(AZURE_CLIENT_SECRET)
export ARM_SUBSCRIPTION_ID ?= $(AZURE_SUBSCRIPTION_ID)
export ARM_TENANT_ID       ?= $(AZURE_TENANT_ID)

deploy: init plan apply createsa token
ifeq (spot,$(WORKER_IMPL))
deploy: untaint
endif
deploy: output

init:
	@mkdir -p $(TF_DATA_DIR)
	@if test "$(WORKER_IMPL)" = spot; then cp -v fragments/aks-worker-$(WORKER_IMPL).tf .; else rm -f aks-worker-$(WORKER_IMPL).tf; fi
	$(terraform) init -get=true $(TF_CLI_ARGS) -reconfigure -force-copy \
		-backend-config="storage_account_name=$${STATE_BUCKET//./}" \
		-backend-config="container_name=$(STATE_CONTAINER)" \
		-backend-config="resource_group_name=$(TF_VAR_resource_group_name)" \
		-backend-config="key=$(DOMAIN_NAME)/$(COMPONENT_NAME)/terraform.tfstate"
.PHONY: init

plan:
	$(terraform) plan $(TF_CLI_ARGS) \
		-var dns_prefix=$${DOMAIN_NAME//./} \
		-refresh=true -out=$(TFPLAN)
.PHONY: plan

apply:
	$(terraform) apply $(TF_CLI_ARGS) -Xshadow=false $(TFPLAN)
	@echo
.PHONY: apply

context:
	$(az) aks get-credentials --resource-group $(TF_VAR_resource_group_name) --name $(TF_VAR_cluster_name)
.PHONY: context

createsa: context
	$(kubectl) -n default get serviceaccount $(SERVICE_ACCOUNT) || \
		($(kubectl) -n default create serviceaccount $(SERVICE_ACCOUNT) && sleep 17)
	$(kubectl) get clusterrolebinding $(SERVICE_ACCOUNT)-cluster-admin-binding || \
		($(kubectl) create clusterrolebinding $(SERVICE_ACCOUNT)-cluster-admin-binding \
			--clusterrole=cluster-admin --serviceaccount=default:$(SERVICE_ACCOUNT) && sleep 7)
.PHONY: createsa

token:
	$(eval SECRET:=$(shell $(kubectl) -n default get serviceaccount $(SERVICE_ACCOUNT) -o json | \
		jq -r '.secrets[] | select(.name | contains("token")).name'))
	$(eval TOKEN:=$(shell $(kubectl) -n default get secret $(SECRET) -o json | \
		jq -r '.data.token'))
.PHONY: token

# https://github.com/Azure/AKS/issues/1719
untaint:
	$(kubectl) apply -f spot-node-untaint.yaml
.PHONY: untaint

output:
	@echo
	@echo Outputs:
	@echo dns_name = $(NAME)
	@echo dns_base_domain = $(BASE_DOMAIN)
	@echo cluster_name = $(TF_VAR_cluster_name)
	@echo token = $(TOKEN) | $(HUB) util otp
	@echo
.PHONY: output

destroy: TF_CLI_ARGS:=-destroy $(TF_CLI_ARGS)
destroy: plan

undeploy: init destroy apply
