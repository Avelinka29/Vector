#!/bin/sh
set -eu

backup_directory=${1:-backups}
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p "$backup_directory"

database_file="$backup_directory/vector-$timestamp.sql.gz"
images_file="$backup_directory/vector-catalog-images-$timestamp.tar.gz"
checksums_file="$backup_directory/vector-$timestamp.sha256"

docker compose exec -T postgres pg_dump -U vector -d vector | gzip > "$database_file"
docker compose exec -T api tar -C /data/catalog-images -czf - . > "$images_file"

if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$database_file" "$images_file" > "$checksums_file"
elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$database_file" "$images_file" > "$checksums_file"
else
    checksums_file=""
fi

echo "Database backup created: $database_file"
echo "Catalog image backup created: $images_file"
if [ -n "$checksums_file" ]; then
    echo "Checksums created: $checksums_file"
fi
