-- =============================================
-- Сводный запуск всех тестов pg_ru_utils
-- =============================================

\pset tuples_only on
\pset format unaligned

SELECT '============================================';
SELECT '  pg_ru_utils — результаты тестирования    ';
SELECT '============================================';

-- Блок 1: Транслитерация
SELECT format('%-30s passed: %s  failed: %s',
              'Транслитерация',
              count(*) FILTER (WHERE result),
              count(*) FILTER (WHERE NOT result)
       )
FROM (SELECT ru_translit('привет') = 'privet' AS result
      UNION ALL
      SELECT ru_translit('ПРИВЕТ') = 'PRIVET'
      UNION ALL
      SELECT ru_translit('Привет') = 'Privet'
      UNION ALL
      SELECT ru_translit('Иванов Иван Иванович') = 'Ivanov Ivan Ivanovich'
      UNION ALL
      SELECT ru_translit('Москва') = 'Moskva'
      UNION ALL
      SELECT ru_translit(NULL) IS NULL
      UNION ALL
      SELECT ru_translit('Привет, мир!') = 'Privet, mir!'
      UNION ALL
      SELECT ru_translit('abc123') = 'abc123'
      UNION ALL
      SELECT ru_translit('жшщчцхюяеё') = 'zhshshchchtskhyuyaee'
      UNION ALL
      SELECT ru_translit('объект') = 'obekt'
      UNION ALL
      SELECT ru_translit('мальчик') = 'malchik'
      UNION ALL
      SELECT ru_translit('Щербаков') = 'Shcherbakov'
      UNION ALL
      SELECT ru_translit('Ёлка') = 'Elka'
      UNION ALL
      SELECT ru_translit('Йод') = 'Iod'
      UNION ALL
      SELECT length(ru_translit(repeat('а', 1000))) > 0
      UNION ALL
      SELECT ru_translit_slug('Привет Мир') = 'privet-mir'
      UNION ALL
      SELECT ru_translit_slug('Привет, Мир!') = 'privet-mir'
      UNION ALL
      SELECT ru_translit_slug('Привет   Мир') = 'privet-mir'
      UNION ALL
      SELECT ru_translit_slug('  Привет  ') = 'privet'
      UNION ALL
      SELECT ru_translit_slug('Hello World') = 'hello-world'
      UNION ALL
      SELECT ru_translit_slug('Статья 42') = 'statya-42'
      UNION ALL
      SELECT ru_translit_slug('!!!') = ''
      UNION ALL
      SELECT ru_translit_slug(NULL) IS NULL
      UNION ALL
      SELECT ru_translit_slug('один--два') = 'odin-dva') t;

-- Блок 2: ИНН
SELECT format('%-30s passed: %s  failed: %s',
              'ИНН',
              count(*) FILTER (WHERE result),
              count(*) FILTER (WHERE NOT result)
       )
FROM (SELECT inn_validate('7707083893') = true AS result
      UNION ALL
      SELECT inn_validate('7736207543') = true
      UNION ALL
      SELECT inn_validate('7707083894') = false
      UNION ALL
      SELECT inn_validate('0000000000') = true
      UNION ALL
      SELECT inn_validate('770708389') = false
      UNION ALL
      SELECT inn_validate('77070838931') = false
      UNION ALL
      SELECT inn_validate('770708389X') = false
      UNION ALL
      SELECT inn_validate('') = false
      UNION ALL
      SELECT inn_validate(NULL) IS NULL
      UNION ALL
      SELECT inn_validate('7707 083893') = true
      UNION ALL
      SELECT inn_validate('7707-083893') = true
      UNION ALL
      SELECT inn_validate('500100732259') = true
      UNION ALL
      SELECT inn_validate('760307073214') = true
      UNION ALL
      SELECT inn_validate('500100732269') = false
      UNION ALL
      SELECT inn_validate('500100732258') = false
      UNION ALL
      SELECT inn_validate('000000000000') IS NOT NULL
      UNION ALL
      SELECT inn_type('7707083893') = 'юрлицо'
      UNION ALL
      SELECT inn_type('500100732259') = 'физлицо'
      UNION ALL
      SELECT inn_type('1234567890') = 'неверный ИНН'
      UNION ALL
      SELECT inn_type('123456789') = 'неверный ИНН'
      UNION ALL
      SELECT inn_type(NULL) IS NULL
      UNION ALL
      SELECT inn_type('') = 'неверный ИНН'
      UNION ALL
      SELECT inn_type('7707 083893') = 'юрлицо'
      UNION ALL
      SELECT inn_type('500100-732259') = 'физлицо') t;

-- Блок 3: СНИЛС
SELECT format('%-30s passed: %s  failed: %s',
              'СНИЛС',
              count(*) FILTER (WHERE result),
              count(*) FILTER (WHERE NOT result)
       )
FROM (SELECT snils_validate('11223344595') = true AS result
      UNION ALL
      SELECT snils_validate('112-233-445 95') = true
      UNION ALL
      SELECT snils_validate('112-233-445-95') = true
      UNION ALL
      SELECT snils_validate('112 233 445 95') = true
      UNION ALL
      SELECT snils_validate('09400000000') = true
      UNION ALL
      SELECT snils_validate('18400000000') = true
      UNION ALL
      SELECT snils_validate('11223344500') = false
      UNION ALL
      SELECT snils_validate('1122334459') = false
      UNION ALL
      SELECT snils_validate('112233445951') = false
      UNION ALL
      SELECT snils_validate('1122334459X') = false
      UNION ALL
      SELECT snils_validate('') = false
      UNION ALL
      SELECT snils_validate(NULL) IS NULL
      UNION ALL
      SELECT snils_validate('00000000000') = true
      UNION ALL
      SELECT snils_validate('00100199800') = true
      UNION ALL
      SELECT snils_format('11223344595') = '112-233-445 95'
      UNION ALL
      SELECT snils_format('112-233-445 95') = '112-233-445 95'
      UNION ALL
      SELECT snils_format('112 233 445 95') = '112-233-445 95'
      UNION ALL
      SELECT snils_format('112-233-44595') = '112-233-445 95'
      UNION ALL
      SELECT snils_format('1122334459') IS NULL
      UNION ALL
      SELECT snils_format('112233445951') IS NULL
      UNION ALL
      SELECT snils_format('') IS NULL
      UNION ALL
      SELECT snils_format(NULL) IS NULL
      UNION ALL
      SELECT length(snils_format('11223344595')) = 14
      UNION ALL
      SELECT snils_validate(snils_format('11223344595')) = true
      UNION ALL
      SELECT split_part(snils_format('11223344595'), '-', 1) = '112') t;

-- Блок 4: Телефоны
SELECT format('%-30s passed: %s  failed: %s',
              'Телефоны',
              count(*) FILTER (WHERE result),
              count(*) FILTER (WHERE NOT result)
       )
FROM (SELECT phone_normalize('+7 (999) 123-45-67') = '+79991234567' AS result
      UNION ALL
      SELECT phone_normalize('8 (999) 123-45-67') = '+79991234567'
      UNION ALL
      SELECT phone_normalize('89991234567') = '+79991234567'
      UNION ALL
      SELECT phone_normalize('+79991234567') = '+79991234567'
      UNION ALL
      SELECT phone_normalize('79991234567') = '+79991234567'
      UNION ALL
      SELECT phone_normalize('9991234567') = '+79991234567'
      UNION ALL
      SELECT phone_normalize('+7.999.123.45.67') = '+79991234567'
      UNION ALL
      SELECT phone_normalize('') IS NULL
      UNION ALL
      SELECT phone_normalize('8991234567') IS NULL
      UNION ALL
      SELECT phone_normalize('899912345678') IS NULL
      UNION ALL
      SELECT phone_normalize('+12025550123') IS NULL
      UNION ALL
      SELECT phone_normalize(NULL) IS NULL
      UNION ALL
      SELECT phone_validate('+79991234567') = true
      UNION ALL
      SELECT phone_validate('+73991234567') = true
      UNION ALL
      SELECT phone_validate('+74951234567') = true
      UNION ALL
      SELECT phone_validate('+78001234567') = true
      UNION ALL
      SELECT phone_validate('8 (999) 123-45-67') = true
      UNION ALL
      SELECT phone_validate('+71991234567') = false
      UNION ALL
      SELECT phone_validate('+72991234567') = false
      UNION ALL
      SELECT phone_validate('+75991234567') = false
      UNION ALL
      SELECT phone_validate('+76991234567') = false
      UNION ALL
      SELECT phone_validate('+77991234567') = false
      UNION ALL
      SELECT phone_validate('8991234567') = false
      UNION ALL
      SELECT phone_validate(NULL) IS NULL
      UNION ALL
      SELECT phone_validate('') = false
      UNION ALL
      SELECT phone_validate('+12025550123') = false
      UNION ALL
      SELECT phone_validate(phone_normalize('8 (999) 123-45-67')) = true) t;

-- Блок 5: Маскирование
SELECT format('%-30s passed: %s  failed: %s',
              'Маскирование',
              count(*) FILTER (WHERE result),
              count(*) FILTER (WHERE NOT result)
       )
FROM (SELECT mask_email('ivan.ivanov@mail.ru') = 'iva********@mail.ru' AS result
      UNION ALL
      SELECT mask_email('ivan@mail.ru') = 'iv**@mail.ru'
      UNION ALL
      SELECT mask_email('ab@mail.ru') = 'a*@mail.ru'
      UNION ALL
      SELECT mask_email('a@mail.ru') = 'a@mail.ru'
      UNION ALL
      SELECT mask_email('test@example.com') LIKE '%@example.com'
      UNION ALL
      SELECT mask_email('notanemail') IS NULL
      UNION ALL
      SELECT mask_email('@mail.ru') IS NULL
      UNION ALL
      SELECT mask_email(NULL) IS NULL
      UNION ALL
      SELECT mask_email('') IS NULL
      UNION ALL
      SELECT length(mask_email('ivan@mail.ru')) = length('ivan@mail.ru')
      UNION ALL
      SELECT mask_email('abcde@mail.ru') = 'ab***@mail.ru'
      UNION ALL
      SELECT mask_email('abcdef@mail.ru') = 'abc***@mail.ru'
      UNION ALL
      SELECT mask_phone('+79991234567') = '+7999***4567'
      UNION ALL
      SELECT mask_phone('8 (999) 123-45-67') = '+7999***4567'
      UNION ALL
      SELECT length(mask_phone('+79991234567')) = 12
      UNION ALL
      SELECT substr(mask_phone('+79991234567'), 1, 5) = '+7999'
      UNION ALL
      SELECT substr(mask_phone('+79991234567'), 9) = '4567'
      UNION ALL
      SELECT substr(mask_phone('+79991234567'), 6, 3) = '***'
      UNION ALL
      SELECT mask_phone('notaphone') IS NULL
      UNION ALL
      SELECT mask_phone(NULL) IS NULL
      UNION ALL
      SELECT mask_phone('') IS NULL
      UNION ALL
      SELECT mask_card('4111111111111111') = '4111 ******** 1111'
      UNION ALL
      SELECT mask_card('4111 1111 1111 1111') = '4111 ******** 1111'
      UNION ALL
      SELECT mask_card('4111-1111-1111-1111') = '4111 ******** 1111'
      UNION ALL
      SELECT mask_card('5500005555555559') = '5500 ******** 5559'
      UNION ALL
      SELECT mask_card('378282246310005') = '3782 ******* 0005'
      UNION ALL
      SELECT mask_card('4111111111111') = '4111 ***** 1111'
      UNION ALL
      SELECT mask_card('6250941006528599204') = '6250 *********** 9204'
      UNION ALL
      SELECT substr(mask_card('4111111111111111'), 1, 4) = '4111'
      UNION ALL
      SELECT right(mask_card('4111111111111111'), 4) = '1111'
      UNION ALL
      SELECT mask_card('411111111111') IS NULL
      UNION ALL
      SELECT mask_card('41111111111111111') IS NULL
      UNION ALL
      SELECT mask_card(NULL) IS NULL
      UNION ALL
      SELECT mask_card('') IS NULL) t;

SELECT '============================================';

\pset tuples_only off
\pset format aligned