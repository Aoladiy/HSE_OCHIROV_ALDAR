IMAGE   := pg_ru_utils
PORT    := 5434
PG_USER := postgres
PG_PASS := postgres
PG_DB   := demo

export PGPASSWORD := $(PG_PASS)
PSQL := psql -h localhost -p $(PORT) -U $(PG_USER) -d $(PG_DB)

.PHONY: build up test demo psql down clean help

help: ## Показать справку
	@grep -E '^[a-z][a-z_-]+:.*## ' $(MAKEFILE_LIST) \
		| awk -F ':.*## ' '{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

build: ## Собрать Docker-образ
	docker build -t $(IMAGE) .

up: ## Запустить контейнер (порт $(PORT))
	@if [ -z "$$(docker ps -q -f name=$(IMAGE))" ]; then \
		docker rm -f $(IMAGE) 2>/dev/null || true; \
		docker run -d --name $(IMAGE) -p $(PORT):5432 $(IMAGE); \
		echo "Ожидание готовности PostgreSQL..."; \
		until docker exec $(IMAGE) pg_isready -U $(PG_USER) >/dev/null 2>&1; do sleep 0.3; done; \
		echo "Готово: $(PSQL)"; \
	else \
		echo "Контейнер уже запущен"; \
	fi

test: ## Запустить тесты
	$(PSQL) -f tests/run_all_tests.sql

examples: ## Запустить демо-сценарии
	$(PSQL) -f examples.sql

psql: ## Открыть интерактивную psql-сессию
	$(PSQL)

down: ## Остановить и удалить контейнер
	docker rm -f $(IMAGE) 2>/dev/null || true

clean: down ## Удалить контейнер и образ
	docker rmi $(IMAGE) 2>/dev/null || true