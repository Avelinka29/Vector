# VECTOR Backend

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

- API: `http://localhost:8000`
- документация: `http://localhost:8000/docs`
- проверка: `http://localhost:8000/health`

Для production обязательно задайте собственный `VECTOR_JWT_SECRET` длиной не менее
32 символов через секреты хостинга. Не коммитьте `.env`.

## Первый администратор

При запущенной базе:

```bash
docker compose exec api python -m app.commands.create_admin
```

Пароль вводится скрыто и сохраняется только в виде Argon2-хеша.

## Импорт текущего справочника

Файлы необходимо скопировать или смонтировать в контейнер. При локальном запуске Python:

```bash
docker compose exec api python -m app.commands.import_catalog \
  /data/institutions.seed.json \
  /data/specialties.seed.json
```

Повторный запуск обновляет строки по `id`; дубли не создаются. Коды специальностей
преобразуются в строки, а отсутствующие значения сохраняются пустой строкой.

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

1. Подтверждение email и восстановление пароля через почтовый сервис.
2. Google OAuth и связывание провайдеров с одним пользователем.
3. Приглашения сотрудников работодателя или учреждения.
4. Заявления, вакансии, отклики, жалобы и журнал действий.
5. APNs-уведомления.
6. Swift-клиент API и миграция данных из Firebase.
