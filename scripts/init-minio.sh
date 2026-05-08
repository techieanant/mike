#!/bin/sh
# scripts/init-minio.sh
# Initialises MinIO on first run: creates the application bucket.
#
# Required env vars:
#   MINIO_ENDPOINT      – e.g. http://minio:9000
#   MINIO_ROOT_USER     – MinIO root / access-key
#   MINIO_ROOT_PASSWORD – MinIO secret-key
#   MINIO_BUCKET_NAME   – bucket to create (default: mike)
set -e

BUCKET="${MINIO_BUCKET_NAME:-mike}"

echo "Waiting for MinIO at ${MINIO_ENDPOINT} ..."
until mc alias set myminio "${MINIO_ENDPOINT}" "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}" > /dev/null 2>&1; do
  echo "  MinIO not ready, retrying in 3s..."
  sleep 3
done

echo "MinIO ready. Creating bucket '${BUCKET}' if it does not exist..."
mc mb --ignore-existing "myminio/${BUCKET}"

# Keep objects private — signed URLs are used for access
mc anonymous set none "myminio/${BUCKET}"

echo "MinIO initialisation complete."
