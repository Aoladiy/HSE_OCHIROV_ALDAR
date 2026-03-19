.PHONY: up down restart build logs ps seed test client shell clean

up:
	docker compose up -d --build

down:
	docker compose down

restart:
	docker compose down
	docker compose up -d --build

logs:
	docker compose logs -f

ps:
	docker compose ps

seed:
	docker compose exec app python seed_data.py 5000

test:
	docker compose exec app python tests/load_test.py

client:
	docker compose exec -it app python client.py

shell:
	docker compose exec app bash

clean:
	docker compose down -v --remove-orphans
