# Oil Pipeline — Big Data & ML

## Запуск

```bash
make build   # первый запуск (сборка образов)
make up      # последующие запуски
make down    # остановка
make restart # перезапуск с пересборкой
make logs    # просмотр логов
make ps      # просмотр статусов контейнеров
```

## Сервисы

| Сервис   | URL                   | Credentials                |
|----------|-----------------------|----------------------------|
| Jupyter  | http://localhost:8888 | token: oiltoken            |
| MinIO    | http://localhost:9001 | minioadmin / minioadmin123 |
| Superset | http://localhost:8088 | admin / admin123           |

## Порядок запуска ноутбуков

1. `etl.ipynb` - выгрузка и очистка данных
2. `task1_analytics.ipynb` - аналитика добычи
3. `task2_ml.ipynb` - прогноз дебита
4. `task3_anomaly.ipynb` - аномалии и отказы
5. `task4_logistics.ipynb` - логистика
6. `load_marts_to_pg.ipynb` - загрузка мартов в PostgreSQL для Superset