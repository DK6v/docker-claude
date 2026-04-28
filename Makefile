.DEFAULT_GOAL := shell

export UID = $(shell id -u ${USER})
export GID = $(shell id -g ${USER})
export DOCKER_GID = $(shell stat -c '%g' /var/run/docker.sock 2>/dev/null || echo "${GID}")

# Extract secrets from .secret file (format: KEY=value, lines starting with # are ignored)
SECRET_ARGS = $(shell \
	if [ -f .secret ]; then \
		cat .secret | grep -v '^#' | grep -v '^$$' | while IFS='=' read -r key value; do \
			printf -- '-e %s=%s ' "$$key" "$$value"; \
		done; \
	fi \
)

CONTAINER_NAME = claude
WORKSPACE_FILE = .workspace

.PHONY: build start stop shell logs clean restart status exec bash select-workspace

# Build the Docker image
build:
	docker compose build --progress=plain

# Select workspace only
select-workspace:
	@echo "Available workspaces in ~/repo:"
	@echo ""
	@ls -d ~/repo/*/ 2>/dev/null | xargs -n 1 basename | awk '{printf "[%d] %s\n", NR, $$0}'; \
	echo ""; \
	read -p "Enter number: " choice; \
	selected=$$(ls -d ~/repo/*/ 2>/dev/null | xargs -n 1 basename | sed -n "$${choice}p"); \
	if [ -z "$$selected" ]; then \
		echo "Invalid selection"; \
		exit 1; \
	fi; \
	echo "$$selected" > $(WORKSPACE_FILE); \
	echo "Workspace saved: $$selected"

# Create and start container in background if it doesn't exist
start:
	@if [ ! -f $(WORKSPACE_FILE) ]; then \
		$(MAKE) --no-print-directory select-workspace; \
	fi; \
	WORKSPACE_DIR=$$(cat $(WORKSPACE_FILE)); \
	WORKSPACE_PATH=$${HOME}/repo/$$WORKSPACE_DIR; \
	if [ ! -d "$$WORKSPACE_PATH" ]; then \
		echo "Error: Workspace path $$WORKSPACE_PATH does not exist"; \
		exit 1; \
	fi; \
	if [ -z "$$(docker ps -q -f name=$(CONTAINER_NAME))" ]; then \
		if [ -n "$$(docker ps -aq -f status=exited -f name=$(CONTAINER_NAME))" ]; then \
			echo "Starting existing container..."; \
			docker start $(CONTAINER_NAME); \
			sleep 2; \
		else \
			echo "Creating and starting new container with workspace: $$WORKSPACE_DIR"; \
			echo "Mounting $$WORKSPACE_PATH to /workspace"; \
			docker compose run -d --name $(CONTAINER_NAME) \
				-e UID=$(UID) \
				-e GID=$(GID) \
				-e DOCKER_GID=$(DOCKER_GID) \
				$(SECRET_ARGS) \
				-v $$WORKSPACE_PATH:/workspace \
				$(shell docker compose config --services | head -1); \
			sleep 3; \
		fi \
	else \
		echo "Container is already running"; \
	fi

# Stop the running container
stop:
	@if [ -n "$$(docker ps -q -f name=$(CONTAINER_NAME))" ]; then \
		echo "Stopping container..."; \
		docker stop $(CONTAINER_NAME); \
	else \
		echo "Container is not running"; \
	fi

# Open an interactive shell inside the container (auto-starts if needed)
shell:
	@$(MAKE) --no-print-directory start
	@sleep 1
	docker exec -it --user node $(CONTAINER_NAME) bash -i

# Follow container logs
logs:
	docker compose logs -f

# Remove container completely
clean:
	@if [ -n "$$(docker ps -aq -f name=$(CONTAINER_NAME))" ]; then \
		echo "Removing container..."; \
		docker rm -f $(CONTAINER_NAME); \
	else \
		echo "Container does not exist"; \
	fi
	@rm -f $(WORKSPACE_FILE)

# Rebuild and restart everything
restart: stop clean build start

# Show container status
status:
	@docker ps -f name=$(CONTAINER_NAME) --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" || echo "Container not found"

# Execute arbitrary command inside the container
# Usage: make exec cmd="npm install"
exec:
	@if [ -z "$(cmd)" ]; then \
		echo "Usage: make exec cmd='your command'"; \
		exit 1; \
	fi
	@$(MAKE) --no-print-directory start
	@sleep 1
	docker exec -it --user node $(CONTAINER_NAME) $(cmd)

# Open bash shell (fallback to sh if bash not available)
bash:
	@$(MAKE) start
	@sleep 1
	docker exec -it --user node $(CONTAINER_NAME) /bin/bash || docker exec -it --user node $(CONTAINER_NAME) /bin/sh
