.PHONY: help install update update-preview clean clean-all logs status monitor restart show-restarts doctor switch-beta switch-stable

PROJECT_NAME := localai

help:
	@echo "n8n-install - Available commands:"
	@echo ""
	@echo "  make install           Full installation"
	@echo "  make update            Update system and services"
	@echo "  make update-preview    Preview available updates (dry-run)"
	@echo "  make clean             Remove unused Docker resources (preserves data)"
	@echo "  make clean-all         Remove ALL Docker resources including data (DANGEROUS)"
	@echo ""
	@echo "  make logs              View logs (all services)"
	@echo "  make logs s=<service>  View logs for specific service"
	@echo "  make status            Show container status"
	@echo "  make monitor           Live CPU/memory monitoring"
	@echo "  make restart           Restart all services"
	@echo "  make show-restarts     Show restart count per container"
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

clean-all:
	@echo "WARNING: This will delete ALL Docker resources including application data!"
	@echo "Press Ctrl+C to cancel, or wait 10 seconds to continue..."
	@sleep 10
	docker system prune -a --volumes -f

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

restart:
	bash ./scripts/restart.sh

show-restarts:
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
