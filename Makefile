.PHONY: help install update update-preview clean logs status monitor restarts doctor switch-beta switch-stable

PROJECT_NAME := localai

help:
	@echo "n8n-install - Available commands:"
	@echo ""
	@echo "  make install           Full installation"
	@echo "  make update            Update system and services"
	@echo "  make update-preview    Preview available updates (dry-run)"
	@echo "  make clean             Remove unused Docker resources"
	@echo ""
	@echo "  make logs              View logs (all services)"
	@echo "  make logs s=<service>  View logs for specific service"
	@echo "  make status            Show container status"
	@echo "  make monitor           Live CPU/memory monitoring"
	@echo "  make restarts          Show restart count per container"
	@echo "  make doctor            Run system diagnostics"
	@echo ""
	@echo "  make switch-beta       Switch to beta (develop branch)"
	@echo "  make switch-stable     Switch to stable (main branch)"

install:
	sudo bash ./scripts/install.sh

update:
	sudo bash ./scripts/update.sh

update-preview:
	bash ./scripts/update_preview.sh

clean:
	sudo bash ./scripts/docker_cleanup.sh

logs:
ifdef s
	docker compose -p $(PROJECT_NAME) logs -f --tail=200 $(s)
else
	docker compose -p $(PROJECT_NAME) logs -f --tail=100
endif

status:
	docker compose -p $(PROJECT_NAME) ps

monitor:
	docker stats

restarts:
	@docker ps -q | while read id; do \
		name=$$(docker inspect --format '{{.Name}}' $$id | sed 's/^\/\(.*\)/\1/'); \
		restarts=$$(docker inspect --format '{{.RestartCount}}' $$id); \
		echo "$$name restarted $$restarts times"; \
	done

doctor:
	bash ./scripts/doctor.sh

switch-beta:
	git restore docker-compose.yml
	git checkout develop
	sudo bash ./scripts/update.sh

switch-stable:
	git restore docker-compose.yml
	git checkout main
	sudo bash ./scripts/update.sh
