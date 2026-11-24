# VECTOR Backend

## Веб-регистрация учреждений

Веб-кабинет подключается к этому же API. Последовательность: регистрация учреждения → подтверждение email → проверка администратором в мобильном VECTOR → письмо с решением → доступ к веб-кабинету.

Добавлены `POST /api/v1/organizations/register-institution` и `GET /api/v1/organizations/onboarding`. До подтверждения email заявка не попадает в очередь проверки. Одобрение через существующий PATCH организации доступно только роли `admin`. Веб-панели одобрения нет.

Письма хранятся в `email_outbox`; фоновый обработчик использует общий транспорт SMTP/Gmail API и повторяет отправку при сбое. Без настроенного транспорта письмо остаётся в очереди. Настройка Gmail описана в [GMAIL_SETUP.md](GMAIL_SETUP.md).

Для настоящей почты задайте `VECTOR_SMTP_HOST`, `VECTOR_SMTP_PORT`, `VECTOR_SMTP_USERNAME`, `VECTOR_SMTP_PASSWORD`, `VECTOR_SMTP_FROM_EMAIL`, `VECTOR_SMTP_USE_TLS` в локальном `.env` или секретах среды. Compose передаёт их API. `VECTOR_WEB_APP_URL` — адрес веб-кабинета для ссылок в письмах; локально `http://localhost:4173`. После настройки пересоздайте контейнер API. Не добавляйте пароли в Git.

Основной backend приложения VECTOR работает на FastAPI и PostgreSQL. iOS-клиент использует
его для авторизации, каталога, профиля, заявлений, кабинетов и уведомлений. Firebase оставлен
только для доставки системных push-уведомлений.

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
- история AI-диалогов и карточки найденных учреждений/специальностей;
- кабинет работодателя: вакансии, отклики и сотрудники;
- серверные документы, комментарии и сроки заявлений;
- внутренняя лента уведомлений и опциональная автоматическая доставка FCM;
- миграции Alembic.
- несколько заявлений и атомарная перестановка их приоритетов;
- сравнение образовательных вариантов и аналитика опубликованного каталога.

## Быстрый локальный запуск

### AI-помощник через OpenRouter или Ollama

Локальный секрет хранится только в `backend/.env`:

```env
OPENROUTER_API_KEY=sk-or-v1-...
OPENROUTER_MODEL=openrouter/free
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
OPENROUTER_APP_NAME=VECTOR
ASSISTANT_PROVIDER=openrouter
```

`.env` исключён из Git. В `.env.example` ключ всегда должен оставаться пустым.
После изменения настроек пересоздайте API: `docker compose up -d --build`.
Маршрут `POST /api/v1/assistant/chat` сначала подбирает записи PostgreSQL, затем
передаёт модели только ограниченный контекст справочника. Если OpenRouter
недоступен или исчерпан бесплатный лимит, разговорный fallback отвечает по найденным
данным, объясняет подбор и задаёт уточняющие вопросы вместо сообщения об ошибке.
Обычный запрос модели ограничен 20 секундами, автоматическая
рекомендация — 10 секундами. Для вопросов о баллах, документах, сроках, экзаменах
и стоимости API не генерирует отсутствующие факты и сообщает о нехватке проверенных данных.

Для локальной Ollama установите Ollama на Mac, загрузите модель и переключите провайдер:

```bash
ollama pull qwen3:8b
# backend/.env
ASSISTANT_PROVIDER=ollama
OLLAMA_BASE_URL=http://host.docker.internal:11434/v1
OLLAMA_MODEL=qwen3:8b
```

После этого пересоберите `api`. Используется официальный OpenAI-совместимый endpoint
`/v1/chat/completions`; мобильное приложение менять не требуется.

Из папки `backend`:

```bash
docker compose up --build
```

После запуска:

- API: `http://localhost:8002`
- документация: `http://localhost:8002/docs`
- проверка: `http://localhost:8002/health`
- готовность базы и файлового хранилища: `http://localhost:8002/ready`
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

## Проверенные проходные баллы

Проходные баллы не берутся из основного справочника: в исходной выгрузке их нет.
Для них используется отдельная таблица с годом, формой обучения, типом финансирования,
официальной ссылкой и датой проверки. Пример формата — `passing_scores.example.json`.

```bash
docker cp passing_scores.json vector-backend-api-1:/data/passing_scores.json
docker compose exec api python -m app.scripts.import_passing_scores /data/passing_scores.json
```

Импорт повторяемый и обновляет совпадающие записи. Значения без официального HTTPS-источника
не принимаются. Пример содержит демонстрационные идентификаторы и не импортируется автоматически.

## Автоматические уведомления

Все события сначала сохраняются в `notification_outbox` и сразу видны во внутренней ленте
приложения. Для реальных push положите Firebase Admin SDK JSON в Docker volume и укажите путь:

```bash
docker cp /безопасный/путь/firebase-admin.json vector-backend-api-1:/data/uploads/firebase-admin.json
echo 'FIREBASE_SERVICE_ACCOUNT_PATH=/data/uploads/firebase-admin.json' >> .env
docker compose up -d --force-recreate api
```

JSON нельзя добавлять в Git. Для доставки на iPhone в Firebase также должен быть загружен APNs key;
его выдаёт Apple Developer Program. Без него внутренняя лента работает, но системный push на iOS — нет.

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
- `POST /api/v1/assistant/chat`
- `GET /api/v1/assistant/history`
- `GET /api/v1/notifications`
- `GET/POST /api/v1/employer/vacancies`
- `GET/PATCH /api/v1/employer/responses`
- `GET/POST /api/v1/employer/members`
- `GET/POST /api/v1/applications/{id}/documents`
- `GET/POST /api/v1/applications/{id}/comments`
- `PATCH /api/v1/applications/{id}/deadline`

## Следующие этапы

1. Production SMTP для подтверждения email и восстановления пароля.
2. Приглашения ещё не зарегистрированных сотрудников по email.
3. Жалобы и расширенный журнал действий администратора.
4. Загрузка APNs key и проверка FCM на физическом iPhone.
5. Production-развёртывание с HTTPS и внешним мониторингом.

## Резервная копия

Из папки `backend` выполните:

```bash
./scripts/backup.sh
```

Скрипт создаёт сжатый дамп PostgreSQL, архив каталога изображений и файл контрольных
сумм SHA-256 в `backend/backups`. Для восстановления изображения распаковываются обратно
в `/data/catalog-images`, а база загружается из SQL-дампа в чистую PostgreSQL.
Шаблон обязательных production-переменных находится в `.env.production.example`.
