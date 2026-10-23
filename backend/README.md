# VECTOR Backend

## Веб-регистрация учреждений

Веб-кабинет подключается к этому же API. Последовательность: регистрация учреждения → подтверждение email → проверка администратором в мобильном VECTOR → письмо с решением → доступ к веб-кабинету.

Добавлены `POST /api/v1/organizations/register-institution` и `GET /api/v1/organizations/onboarding`. До подтверждения email заявка не попадает в очередь проверки. Одобрение через существующий PATCH организации доступно только роли `admin`. Веб-панели одобрения нет.

Письма хранятся в `email_outbox`; фоновый обработчик повторяет отправку при сбое SMTP. Без SMTP письмо остаётся в очереди, доставка не имитируется.

Для настоящей почты задайте `VECTOR_SMTP_HOST`, `VECTOR_SMTP_PORT`, `VECTOR_SMTP_USERNAME`, `VECTOR_SMTP_PASSWORD`, `VECTOR_SMTP_FROM_EMAIL`, `VECTOR_SMTP_USE_TLS` в локальном `.env` или секретах среды. Compose передаёт их API. `VECTOR_WEB_APP_URL` — адрес веб-кабинета для ссылок в письмах; локально `http://localhost:4173`. После настройки пересоздайте контейнер API. Не добавляйте пароли в Git.

Независимый backend приложения VECTOR на FastAPI и PostgreSQL. Firebase пока продолжает
обслуживать текущую iOS-версию; переключение клиента будет выполняться поэтапно.

## Что уже реализовано

- регистрация и вход по email/паролю;
- короткоживущий JWT access token и обновляемый refresh token;
- роли `applicant`, `employer`, `institution`, `moderator`, `admin`;
- заявки работодателей и учреждений на регистрацию;
- создание работодателя или учреждения администратором;
- модерация статуса организации;
- PostgreSQL-модели учреждений и специальностей;
- поиск учреждений и специальностей учреждения;
- повторяемый импорт справочника по стабильным ID;
- миграции Alembic.

## Быстрый локальный запуск

Из папки `backend`:

```bash
docker compose up --build
```

После запуска:

- API: `http://localhost:8002`
- документация: `http://localhost:8002/docs`
- проверка: `http://localhost:8002/health`
- Adminer: `http://localhost:8083`
- PostgreSQL с Mac: `localhost:5434`

Compose-проект имеет отдельное имя `vector-backend`, чтобы контейнеры VECTOR не
конфликтовали с другими проектами, у которых папка также называется `backend`.

Для production обязательно задайте собственный `VECTOR_JWT_SECRET` длиной не менее
32 символов через секреты хостинга. Не коммитьте `.env`.

## Первый администратор

При запущенной базе:

```bash
docker compose exec api python -m app.commands.create_admin
```

Пароль вводится скрыто и сохраняется только в виде Argon2-хеша.

## Импорт полного справочника

Учреждения и специальности хранятся отдельно и связываются таблицей
`education_institution_specialties`. Исходные записи, замечания, метаданные, ссылки
на источники и отметки проверки также сохраняются.

```bash
docker cp /path/to/belarus_education.json vector-backend-api-1:/tmp/belarus_education.json
docker compose exec api python -m app.commands.import_catalog \
  /tmp/belarus_education.json
```

Повторный запуск обновляет строки по стабильным ID и не создаёт дубли связей.
Коды специальностей сохраняются строками, включая пустую строку при отсутствии
кода. Импорт не подтверждает сведения автоматически: выгрузка остаётся помеченной
как требующая проверки и не считается полным актуальным государственным реестром.

## Основные маршруты

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`
- `POST /api/v1/organizations/applications`
- `POST /api/v1/organizations/admin` — только администратор
- `GET /api/v1/organizations/admin` — администратор или модератор
- `PATCH /api/v1/organizations/{id}/status`
- `GET /api/v1/catalog/institutions`
- `GET /api/v1/catalog/institutions/{id}/specialties`

## Следующие этапы

1. Production SMTP для подтверждения email и восстановления пароля.
2. Google OAuth и связывание провайдеров с одним пользователем.
3. Приглашения сотрудников работодателя или учреждения.
4. Вакансии, отклики, жалобы и журнал действий.
5. Отправка APNs/FCM-уведомлений с сервера.
6. Production-развёртывание с HTTPS, резервными копиями и мониторингом.
