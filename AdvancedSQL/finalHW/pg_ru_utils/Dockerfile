FROM postgres:16

COPY pg_ru_utils.control /usr/share/postgresql/16/extension/
COPY pg_ru_utils--1.0.sql /usr/share/postgresql/16/extension/
COPY init.sql /docker-entrypoint-initdb.d/

ENV POSTGRES_PASSWORD=postgres
ENV POSTGRES_DB=demo
