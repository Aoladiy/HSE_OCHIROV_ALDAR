-- =============================================
-- Расширение: pg_ru_utils
-- Описание: Утилиты для работы с российскими
--   строковыми данными: транслитерация
--   валидация ИНН, СНИЛС, телефонов,
--   маскирование персональных данных.
-- Язык: PL/pgSQL
-- =============================================

-- =============================================
-- Блок 1: Транслитерация
-- =============================================

CREATE OR REPLACE FUNCTION ru_translit(input_text text)
    RETURNS text
    LANGUAGE plpgsql
    IMMUTABLE
    STRICT
AS
$$
DECLARE
    result text     := input_text;
    pairs  text[][] := ARRAY [
        -- Четырёхбуквенные
        ['shch', 'щ'], ['Shch', 'Щ'], ['SHCH', 'Щ'],
        -- Двухбуквенные
        ['zh', 'ж'], ['Zh', 'Ж'], ['ZH', 'Ж'],
        ['kh', 'х'], ['Kh', 'Х'], ['KH', 'Х'],
        ['ts', 'ц'], ['Ts', 'Ц'], ['TS', 'Ц'],
        ['ch', 'ч'], ['Ch', 'Ч'], ['CH', 'Ч'],
        ['sh', 'ш'], ['Sh', 'Ш'], ['SH', 'Ш'],
        ['yu', 'ю'], ['Yu', 'Ю'], ['YU', 'Ю'],
        ['ya', 'я'], ['Ya', 'Я'], ['YA', 'Я'],
        -- Однобуквенные
        ['a', 'а'], ['A', 'А'],
        ['b', 'б'], ['B', 'Б'],
        ['v', 'в'], ['V', 'В'],
        ['g', 'г'], ['G', 'Г'],
        ['d', 'д'], ['D', 'Д'],
        ['e', 'е'], ['E', 'Е'],
        ['e', 'ё'], ['E', 'Ё'],
        ['z', 'з'], ['Z', 'З'],
        ['i', 'и'], ['I', 'И'],
        ['i', 'й'], ['I', 'Й'],
        ['k', 'к'], ['K', 'К'],
        ['l', 'л'], ['L', 'Л'],
        ['m', 'м'], ['M', 'М'],
        ['n', 'н'], ['N', 'Н'],
        ['o', 'о'], ['O', 'О'],
        ['p', 'п'], ['P', 'П'],
        ['r', 'р'], ['R', 'Р'],
        ['s', 'с'], ['S', 'С'],
        ['t', 'т'], ['T', 'Т'],
        ['u', 'у'], ['U', 'У'],
        ['f', 'ф'], ['F', 'Ф'],
        ['e', 'э'], ['E', 'Э'],
        ['y', 'ы'], ['Y', 'Ы'],
        ['', 'ъ'], ['', 'Ъ'],
        ['', 'ь'], ['', 'Ь']
        ];
    i      integer;
BEGIN
    FOR i IN 1 .. array_length(pairs, 1)
        LOOP
            result := replace(result, pairs[i][2], pairs[i][1]);
        END LOOP;
    RETURN result;
END;
$$;

COMMENT ON FUNCTION ru_translit(text) IS
    'Транслитерация кириллического текста в латиницу '
        'Поддерживает верхний и нижний регистр. '
        'Пример: ru_translit(''Щербаков'') -> ''Shcherbakov''';

-- =============================================

CREATE OR REPLACE FUNCTION ru_translit_slug(input_text text)
    RETURNS text
    LANGUAGE plpgsql
    IMMUTABLE
    STRICT
AS
$$
DECLARE
    result text;
BEGIN
    result := ru_translit(lower(input_text));
    result := regexp_replace(result, '[^a-z0-9\s-]', '', 'g');
    result := regexp_replace(result, '\s+', '-', 'g');
    result := regexp_replace(result, '-{2,}', '-', 'g');
    result := trim(both '-' from result);
    RETURN result;
END;
$$;

COMMENT ON FUNCTION ru_translit_slug(text) IS
    'Транслитерация кириллического текста в slug для URL '
        'Переводит в нижний регистр, заменяет пробелы на дефисы, '
        'удаляет спецсимволы. '
        'Пример: ru_translit_slug(''Привет Мир!'') -> ''privet-mir''';

-- =============================================
-- Блок 2: ИНН
-- =============================================

CREATE OR REPLACE FUNCTION inn_validate(inn text)
    RETURNS boolean
    LANGUAGE plpgsql
    IMMUTABLE
    STRICT
AS
$$
DECLARE
    digits    text;
    weights10 integer[] := ARRAY [2,4,10,3,5,9,4,6,8];
    weights11 integer[] := ARRAY [7,2,4,10,3,5,9,4,6,8,0];
    weights12 integer[] := ARRAY [3,7,2,4,10,3,5,9,4,6,8];
    control1  integer;
    control2  integer;
    n         integer;
BEGIN
    digits := regexp_replace(inn, '\D', '', 'g');

    IF length(digits) NOT IN (10, 12) THEN
        RETURN false;
    END IF;

    IF length(digits) = 10 THEN
        control1 := 0;
        FOR n IN 1..9
            LOOP
                control1 := control1 + weights10[n] * substr(digits, n, 1)::integer;
            END LOOP;
        RETURN (control1 % 11 % 10) = substr(digits, 10, 1)::integer;
    END IF;

    IF length(digits) = 12 THEN
        control1 := 0;
        FOR n IN 1..11
            LOOP
                control1 := control1 + weights11[n] * substr(digits, n, 1)::integer;
            END LOOP;
        control1 := control1 % 11 % 10;

        control2 := 0;
        FOR n IN 1..11
            LOOP
                control2 := control2 + weights12[n] * substr(digits, n, 1)::integer;
            END LOOP;
        control2 := control2 % 11 % 10;

        RETURN control1 = substr(digits, 11, 1)::integer
            AND control2 = substr(digits, 12, 1)::integer;
    END IF;

    RETURN false;
END;
$$;

COMMENT ON FUNCTION inn_validate(text) IS
    'Валидация ИНН по контрольной сумме. '
        'Поддерживает ИНН юрлица (10 цифр) и физлица (12 цифр). '
        'Игнорирует нецифровые символы в строке (пробелы, дефисы и пр.). '
        'Пример: inn_validate(''7707083893'') -> true';

-- =============================================

CREATE OR REPLACE FUNCTION inn_type(inn text)
    RETURNS text
    LANGUAGE plpgsql
    IMMUTABLE
    STRICT
AS
$$
DECLARE
    digits text;
BEGIN
    digits := regexp_replace(inn, '\D', '', 'g');

    IF length(digits) = 10 AND inn_validate(digits) THEN
        RETURN 'юрлицо';
    END IF;

    IF length(digits) = 12 AND inn_validate(digits) THEN
        RETURN 'физлицо';
    END IF;

    RETURN 'неверный ИНН';
END;
$$;

COMMENT ON FUNCTION inn_type(text) IS
    'Определяет тип ИНН: юрлицо (10 цифр), физлицо (12 цифр) или неверный ИНН. '
        'Пример: inn_type(''7707083893'') -> ''юрлицо''';

-- =============================================
-- Блок 3: СНИЛС
-- =============================================

CREATE OR REPLACE FUNCTION snils_validate(snils text)
    RETURNS boolean
    LANGUAGE plpgsql
    IMMUTABLE
    STRICT
AS
$$
DECLARE
    digits  text;
    num9    integer;
    total   integer := 0;
    control integer;
    rem     integer;
    n       integer;
BEGIN
    digits := regexp_replace(snils, '\D', '', 'g');

    IF length(digits) <> 11 THEN
        RETURN false;
    END IF;

    num9 := substr(digits, 1, 9)::bigint;
    IF num9 <= 1001998 THEN
        RETURN true;
    END IF;

    FOR n IN 1..9
        LOOP
            total := total + substr(digits, n, 1)::integer * (10 - n);
        END LOOP;

    control := substr(digits, 10, 2)::integer;

    IF total < 100 THEN
        RETURN total = control;
    ELSIF total IN (100, 101) THEN
        RETURN control = 0;
    ELSE
        rem := total % 101;
        IF rem = 100 THEN
            RETURN control = 0;
        ELSE
            RETURN rem = control;
        END IF;
    END IF;
END;
$$;

COMMENT ON FUNCTION snils_validate(text) IS
    'Валидация СНИЛС по контрольной сумме (алгоритм ПФР). '
        'Принимает СНИЛС в любом формате: с дефисами, пробелами или без. '
        'Номера <= 001-001-998 не проверяются по контрольной сумме (по стандарту ПФР). '
        'Пример: snils_validate(''112-233-445 95'') -> true';

-- =============================================

CREATE OR REPLACE FUNCTION snils_format(snils text)
    RETURNS text
    LANGUAGE plpgsql
    IMMUTABLE
    STRICT
AS
$$
DECLARE
    digits text;
BEGIN
    digits := regexp_replace(snils, '\D', '', 'g');

    IF length(digits) <> 11 THEN
        RETURN NULL;
    END IF;

    RETURN substr(digits, 1, 3) || '-'
               || substr(digits, 4, 3) || '-'
               || substr(digits, 7, 3) || ' '
        || substr(digits, 10, 2);
END;
$$;

COMMENT ON FUNCTION snils_format(text) IS
    'Форматирование СНИЛС в стандартный вид XXX-XXX-XXX YY. '
        'Возвращает NULL если длина не равна 11 цифрам. '
        'Пример: snils_format(''11223344595'') -> ''112-233-445 95''';

-- =============================================
-- Блок 4: Телефоны
-- =============================================

CREATE OR REPLACE FUNCTION phone_normalize(phone text)
    RETURNS text
    LANGUAGE plpgsql
    IMMUTABLE
    STRICT
AS
$$
DECLARE
    digits text;
BEGIN
    digits := regexp_replace(phone, '\D', '', 'g');

    IF length(digits) = 11 AND substr(digits, 1, 1) IN ('7', '8') THEN
        RETURN '+7' || substr(digits, 2);
    END IF;

    IF length(digits) = 10 AND substr(digits, 1, 1) = '9' THEN
        RETURN '+7' || digits;
    END IF;

    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION phone_normalize(text) IS
    'Нормализация российского телефонного номера к виду +7XXXXXXXXXX. '
        'Принимает номера в форматах: +7..., 8..., 7..., 9... (10 цифр). '
        'Возвращает NULL если номер не распознан. '
        'Пример: phone_normalize(''8 (999) 123-45-67'') -> ''+79991234567''';

-- =============================================

CREATE OR REPLACE FUNCTION phone_validate(phone text)
    RETURNS boolean
    LANGUAGE plpgsql
    IMMUTABLE
    STRICT
AS
$$
DECLARE
    normalized text;
BEGIN
    normalized := phone_normalize(phone);

    IF normalized IS NULL THEN
        RETURN false;
    END IF;

    IF normalized !~ '^\+7[3489]\d{9}$' THEN
        RETURN false;
    END IF;

    RETURN true;
END;
$$;

COMMENT ON FUNCTION phone_validate(text) IS
    'Валидация российского телефонного номера. '
        'Проверяет что номер нормализуется к +7XXXXXXXXXX и '
        'код DEF/ABC реалистичен (3xx — стационарные, 4xx — стационарные, '
        '8xx — специальные, 9xx — мобильные). '
        'Пример: phone_validate(''8 (999) 123-45-67'') -> true';

-- =============================================
-- Блок 5: Маскирование персональных данных
-- =============================================

CREATE OR REPLACE FUNCTION mask_email(email text)
    RETURNS text
    LANGUAGE plpgsql
    IMMUTABLE
    STRICT
AS
$$
DECLARE
    local_part  text;
    domain_part text;
    at_pos      integer;
    visible_len integer;
    masked_len  integer;
BEGIN
    at_pos := position('@' in email);

    IF at_pos < 2 THEN
        RETURN NULL;
    END IF;

    local_part := substr(email, 1, at_pos - 1);
    domain_part := substr(email, at_pos);

    visible_len := CASE
                       WHEN length(local_part) <= 2 THEN 1
                       WHEN length(local_part) <= 5 THEN 2
                       ELSE 3
        END;

    masked_len := length(local_part) - visible_len;

    RETURN substr(local_part, 1, visible_len)
               || repeat('*', masked_len)
        || domain_part;
END;
$$;

COMMENT ON FUNCTION mask_email(text) IS
    'Маскирование email-адреса: скрывает часть локальной части звёздочками. '
        'Оставляет 1 символ если длина <=2, 2 символа если <=5, иначе 3 символа. '
        'Пример: mask_email(''ivan.ivanov@mail.ru'') -> ''iva*******@mail.ru''';

-- =============================================

CREATE OR REPLACE FUNCTION mask_phone(phone text)
    RETURNS text
    LANGUAGE plpgsql
    IMMUTABLE
    STRICT
AS
$$
DECLARE
    normalized text;
BEGIN
    normalized := phone_normalize(phone);

    IF normalized IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN substr(normalized, 1, 5)
               || '***'
        || substr(normalized, 9);
END;
$$;

COMMENT ON FUNCTION mask_phone(text) IS
    'Маскирование российского телефонного номера. '
        'Нормализует к +7XXXXXXXXXX, затем скрывает 3 средних цифры (позиции 6-8). '
        'Пример: mask_phone(''8 (999) 123-45-67'') -> ''+7999***4567''';

-- =============================================

CREATE OR REPLACE FUNCTION mask_card(card text)
    RETURNS text
    LANGUAGE plpgsql
    IMMUTABLE
    STRICT
AS
$$
DECLARE
    digits     text;
    masked_len integer;
BEGIN
    digits := regexp_replace(card, '\D', '', 'g');

    IF length(digits) NOT IN (13, 14, 15, 16, 19) THEN
        RETURN NULL;
    END IF;

    masked_len := length(digits) - 8;

    RETURN substr(digits, 1, 4)
               || ' '
               || repeat('*', masked_len)
               || ' '
        || substr(digits, length(digits) - 3);
END;
$$;

COMMENT ON FUNCTION mask_card(text) IS
    'Маскирование номера банковской карты. '
        'Оставляет первые 4 и последние 4 цифры, остальное заменяет звёздочками. '
        'Количество звёздочек соответствует реальному количеству скрытых цифр. '
        'Поддерживает карты длиной 13, 14, 15, 16, 19 цифр. '
        'Пример: mask_card(''4111 1111 1111 1111'') -> ''4111 ******** 1111''';