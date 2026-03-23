\echo
\echo '=== Демонстрация pg_ru_utils ==='
\echo
\echo '--- 1. Транслитерация: slug для статей ---'

SELECT title,
       ru_translit_slug(title) AS slug
FROM (VALUES ('Введение в PostgreSQL'),
             ('Оконные функции: полный гид'),
             ('Как ускорить запросы в 10 раз?'),
             ('PL/pgSQL для начинающих'),
             ('Индексы: B-tree, Hash, GIN, GiST')) AS articles(title);

\echo
\echo '--- 2. Транслитерация: ФИО для загранпаспорта ---'

SELECT full_name,
       ru_translit(full_name) AS transliterated
FROM (VALUES ('Иванов Иван Иванович'),
             ('Петрова Мария Сергеевна'),
             ('Сидоренко Александр Юрьевич'),
             ('Щербакова Екатерина Михайловна')) AS persons(full_name);

\echo
\echo '--- 3. ИНН: проверка реестра контрагентов ---'

CREATE TEMP TABLE contractors
(
    name text,
    inn  text
);

INSERT INTO contractors
VALUES ('ПАО Сбербанк', '7707083893'),
       ('ООО Яндекс', '7736207543'),
       ('ИП Иванов И.И.', '500100732259'),
       ('ООО Ромашка', '1234567890'),
       ('ЗАО Рога и Копыта', '999999999X'),
       ('ООО Технологии будущего', '77070838930');

SELECT name,
       inn,
       inn_validate(inn) AS valid,
       inn_type(inn)     AS type
FROM contractors
ORDER BY valid DESC, name;

DROP TABLE contractors;

\echo
\echo '--- 4. СНИЛС: нормализация базы сотрудников ---'

SELECT employee,
       raw_snils,
       snils_validate(raw_snils) AS valid,
       snils_format(raw_snils)   AS formatted
FROM (VALUES ('Иванов И.И.', '11223344595'),
             ('Петров П.П.', '112-233-445 95'),
             ('Сидоров С.С.', '112 233 445 95'),
             ('Козлов К.К.', '00000000000'),
             ('Новиков Н.Н.', '1234567')) AS employees(employee, raw_snils);

\echo
\echo '--- 5. Телефоны: нормализация CRM-базы ---'

SELECT client,
       raw_phone,
       phone_normalize(raw_phone) AS normalized,
       phone_validate(raw_phone)  AS valid
FROM (VALUES ('Клиент А', '+7 (999) 123-45-67'),
             ('Клиент Б', '8(495)1234567'),
             ('Клиент В', '89161234567'),
             ('Клиент Г', '9031234567'),
             ('Клиент Д', '7-800-555-35-35'),
             ('Клиент Е', '+12025550123'),
             ('Клиент Ж', '123')) AS clients(client, raw_phone);

\echo
\echo '--- 6. Маскирование: выгрузка для аналитиков ---'

CREATE TEMP TABLE users
(
    id    serial,
    name  text,
    email text,
    phone text,
    card  text
);

INSERT INTO users (name, email, phone, card)
VALUES ('Иванов Иван', 'ivan.ivanov@gmail.com', '+79991234567', '4111111111111111'),
       ('Петрова Мария', 'maria.p@yandex.ru', '8 (916) 987-65-43', '5500005555555559'),
       ('Сидоров Алекс', 'alex@corp.example.com', '89031112233', '378282246310005'),
       ('Козлова Анна', 'ak@mail.ru', '+7(812)3334455', '6250941006528599204');

SELECT id,
       name,
       mask_email(email) AS email,
       mask_phone(phone) AS phone,
       mask_card(card)   AS card
FROM users
ORDER BY id;

DROP TABLE users;

\echo
\echo '--- 7. Комплексный сценарий: валидация формы ---'

WITH form_data AS (SELECT 'Иванов Иван Иванович'  AS full_name,
                          '7707083893'            AS inn,
                          '11223344595'           AS snils,
                          '+7 (999) 123-45-67'    AS phone,
                          'ivan.ivanov@gmail.com' AS email)
SELECT full_name,
       ru_translit(full_name) AS name_translit,
       inn,
       inn_validate(inn)      AS inn_ok,
       inn_type(inn)          AS inn_type,
       snils_format(snils)    AS snils_formatted,
       snils_validate(snils)  AS snils_ok,
       phone_normalize(phone) AS phone_normalized,
       phone_validate(phone)  AS phone_ok,
       mask_email(email)      AS email_masked
FROM form_data;