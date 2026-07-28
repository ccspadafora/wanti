.PHONY: help up down logs migrate shell test worker beat build prod-up prod-down backup

help:
	@echo "Wanti backend — comandos frecuentes"
	@echo "  make up         Levantar stack de desarrollo"
	@echo "  make down       Detener stack"
	@echo "  make logs       Seguir logs de api"
	@echo "  make migrate    Aplicar migraciones"
	@echo "  make shell      Django shell"
	@echo "  make test       Ejecutar tests"
	@echo "  make build      Build de imagen Docker"
	@echo "  make backup     Dump de postgres local"
	@echo "  make prod-up    Levantar compose de producción"
	@echo "  make prod-down  Detener compose de producción"

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f api

migrate:
	docker compose exec api python manage.py migrate

shell:
	docker compose exec api python manage.py shell

test:
	docker compose exec api python manage.py test

worker:
	docker compose logs -f celery-worker

beat:
	docker compose logs -f celery-beat

build:
	docker compose build

prod-up:
	docker compose -f docker-compose.prod.yml up -d

prod-down:
	docker compose -f docker-compose.prod.yml down

backup:
	@mkdir -p backups
	docker exec wanti-postgres pg_dump -U postgres -Fc wanti_db \
	  > backups/wanti_db_$$(date +%Y%m%d_%H%M%S).dump
	@echo "Backup escrito en backups/"
