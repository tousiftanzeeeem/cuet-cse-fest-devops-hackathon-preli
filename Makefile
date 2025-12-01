
.DEFAULT_GOAL := help

# Variables
MODE ?= dev
SERVICE ?= backend
COMPOSE_FILE_DEV = docker/compose.development.yaml
COMPOSE_FILE_PROD = docker/compose.production.yaml
COMPOSE_FILE = $(if $(filter prod,$(MODE)),$(COMPOSE_FILE_PROD),$(COMPOSE_FILE_DEV))
DOCKER_COMPOSE = docker compose -f $(COMPOSE_FILE) --env-file .env
ARGS ?=

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[0;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

##@ Help

help: ## Display this help message
	@echo "$(BLUE)E-Commerce Microservices - Docker Management$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(YELLOW)<target>$(NC) [$(GREEN)MODE=dev|prod$(NC)] [$(GREEN)SERVICE=backend|gateway|mongo$(NC)]\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Docker Services

up: ## Start services (MODE=dev|prod, ARGS="--build")
	@echo "$(GREEN)Starting $(MODE) environment...$(NC)"
	$(DOCKER_COMPOSE) up -d $(ARGS)
	@echo "$(GREEN)Services started successfully!$(NC)"

down: ## Stop services (MODE=dev|prod, ARGS="--volumes")
	@echo "$(YELLOW)Stopping $(MODE) environment...$(NC)"
	$(DOCKER_COMPOSE) down $(ARGS)
	@echo "$(GREEN)Services stopped successfully!$(NC)"

build: ## Build containers (MODE=dev|prod, SERVICE=backend|gateway)
	@echo "$(GREEN)Building $(MODE) containers...$(NC)"
	$(DOCKER_COMPOSE) build $(ARGS) $(filter-out $@,$(MAKECMDGOALS))
	@echo "$(GREEN)Build completed successfully!$(NC)"

logs: ## View logs (MODE=dev|prod, SERVICE=backend|gateway|mongo)
	@echo "$(BLUE)Showing logs for $(SERVICE)...$(NC)"
	$(DOCKER_COMPOSE) logs -f $(SERVICE)

restart: ## Restart services (MODE=dev|prod)
	@echo "$(YELLOW)Restarting $(MODE) services...$(NC)"
	$(DOCKER_COMPOSE) restart $(filter-out $@,$(MAKECMDGOALS))
	@echo "$(GREEN)Services restarted successfully!$(NC)"

shell: ## Open shell in container (MODE=dev|prod, SERVICE=backend|gateway)
	@echo "$(BLUE)Opening shell in $(SERVICE) container...$(NC)"
	$(DOCKER_COMPOSE) exec $(SERVICE) sh

ps: ## Show running containers (MODE=dev|prod)
	@echo "$(BLUE)Running containers ($(MODE)):$(NC)"
	$(DOCKER_COMPOSE) ps

##@ Development Aliases

dev-up: ## Start development environment
	@$(MAKE) up MODE=dev ARGS="--build"

dev-down: ## Stop development environment
	@$(MAKE) down MODE=dev

dev-build: ## Build development containers
	@$(MAKE) build MODE=dev

dev-logs: ## View development logs (SERVICE=backend|gateway|mongo)
	@$(MAKE) logs MODE=dev SERVICE=$(SERVICE)

dev-restart: ## Restart development services
	@$(MAKE) restart MODE=dev

dev-shell: ## Open shell in backend container (dev)
	@$(MAKE) shell MODE=dev SERVICE=backend

dev-ps: ## Show running development containers
	@$(MAKE) ps MODE=dev

backend-shell: ## Open shell in backend container
	@$(MAKE) shell MODE=$(MODE) SERVICE=backend

gateway-shell: ## Open shell in gateway container
	@$(MAKE) shell MODE=$(MODE) SERVICE=gateway

mongo-shell: ## Open MongoDB shell
	@echo "$(BLUE)Opening MongoDB shell...$(NC)"
	$(DOCKER_COMPOSE) exec mongo mongosh -u $(shell grep MONGO_INITDB_ROOT_USERNAME .env | cut -d '=' -f2) -p $(shell grep MONGO_INITDB_ROOT_PASSWORD .env | cut -d '=' -f2)

##@ Production Aliases

prod-up: ## Start production environment
	@$(MAKE) up MODE=prod ARGS="--build"

prod-down: ## Stop production environment
	@$(MAKE) down MODE=prod

prod-build: ## Build production containers
	@$(MAKE) build MODE=prod

prod-logs: ## View production logs (SERVICE=backend|gateway|mongo)
	@$(MAKE) logs MODE=prod SERVICE=$(SERVICE)

prod-restart: ## Restart production services
	@$(MAKE) restart MODE=prod

prod-shell: ## Open shell in backend container (prod)
	@$(MAKE) shell MODE=prod SERVICE=backend

prod-ps: ## Show running production containers
	@$(MAKE) ps MODE=prod

##@ Backend

backend-build: ## Build backend TypeScript
	@echo "$(GREEN)Building backend TypeScript...$(NC)"
	cd backend && npm run build
	@echo "$(GREEN)Backend build completed!$(NC)"

backend-install: ## Install backend dependencies
	@echo "$(GREEN)Installing backend dependencies...$(NC)"
	cd backend && npm install
	@echo "$(GREEN)Dependencies installed!$(NC)"

backend-type-check: ## Type check backend code
	@echo "$(BLUE)Type checking backend code...$(NC)"
	cd backend && npm run type-check

backend-dev: ## Run backend in development mode (local)
	@echo "$(GREEN)Starting backend in development mode (local)...$(NC)"
	cd backend && npm run dev

##@ Database

db-reset: ## Reset MongoDB database (WARNING: deletes all data)
	@echo "$(RED)WARNING: This will delete all data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo ""; \
		echo "$(YELLOW)Resetting database...$(NC)"; \
		$(DOCKER_COMPOSE) exec mongo mongosh -u $(shell grep MONGO_INITDB_ROOT_USERNAME .env | cut -d '=' -f2) -p $(shell grep MONGO_INITDB_ROOT_PASSWORD .env | cut -d '=' -f2) --eval "db.getSiblingDB('$(shell grep MONGO_DATABASE .env | cut -d '=' -f2)').dropDatabase()"; \
		echo "$(GREEN)Database reset complete!$(NC)"; \
	else \
		echo ""; \
		echo "$(YELLOW)Operation cancelled.$(NC)"; \
	fi

db-backup: ## Backup MongoDB database
	@echo "$(GREEN)Creating database backup...$(NC)"
	@mkdir -p backups
	$(DOCKER_COMPOSE) exec -T mongo mongodump -u $(shell grep MONGO_INITDB_ROOT_USERNAME .env | cut -d '=' -f2) -p $(shell grep MONGO_INITDB_ROOT_PASSWORD .env | cut -d '=' -f2) --archive > backups/backup-$(shell date +%Y%m%d-%H%M%S).archive
	@echo "$(GREEN)Backup created in backups/$(NC)"

##@ Cleanup

clean: ## Remove containers and networks (both dev and prod)
	@echo "$(YELLOW)Cleaning up containers and networks...$(NC)"
	docker compose -f $(COMPOSE_FILE_DEV) --env-file .env down 2>/dev/null || true
	docker compose -f $(COMPOSE_FILE_PROD) --env-file .env down 2>/dev/null || true
	@echo "$(GREEN)Cleanup complete!$(NC)"

clean-all: ## Remove containers, networks, volumes, and images
	@echo "$(RED)WARNING: This will remove all containers, networks, volumes, and images!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo ""; \
		echo "$(YELLOW)Removing all resources...$(NC)"; \
		docker compose -f $(COMPOSE_FILE_DEV) --env-file .env down -v --rmi all 2>/dev/null || true; \
		docker compose -f $(COMPOSE_FILE_PROD) --env-file .env down -v --rmi all 2>/dev/null || true; \
		echo "$(GREEN)All resources removed!$(NC)"; \
	else \
		echo ""; \
		echo "$(YELLOW)Operation cancelled.$(NC)"; \
	fi

clean-volumes: ## Remove all volumes
	@echo "$(RED)WARNING: This will delete all persistent data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo ""; \
		echo "$(YELLOW)Removing volumes...$(NC)"; \
		docker compose -f $(COMPOSE_FILE_DEV) --env-file .env down -v 2>/dev/null || true; \
		docker compose -f $(COMPOSE_FILE_PROD) --env-file .env down -v 2>/dev/null || true; \
		echo "$(GREEN)Volumes removed!$(NC)"; \
	else \
		echo ""; \
		echo "$(YELLOW)Operation cancelled.$(NC)"; \
	fi


status: ps ## Alias for ps

health: ## Check service health
	@echo "$(BLUE)Checking service health ($(MODE))...$(NC)"
	@echo "$(YELLOW)Gateway:$(NC)"
	@curl -s http://localhost:5921/health | jq . || echo "$(RED)Gateway is not responding$(NC)"
	@echo "$(YELLOW)Backend (via Gateway):$(NC)"
	@curl -s http://localhost:5921/api/health | jq . || echo "$(RED)Backend is not responding$(NC)"


