#!/bin/sh
# Copyright 2026 Snowflake Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

echo "=========================================="
echo "🔧 Bootstrapping Polaris"
echo "=========================================="

# Get OAuth token from Keycloak (Polaris uses external authentication)
echo "🔐 Getting OAuth token from Keycloak..."
TOKEN=$(curl -s http://keycloak:8080/realms/iceberg/protocol/openid-connect/token \
  --user ${CLIENT_ID}:${CLIENT_SECRET} \
  -d grant_type=client_credentials | jq -r .access_token)

if [ -z "${TOKEN}" ] || [ "${TOKEN}" == "null" ]; then
  echo "❌ Failed to obtain access token"
  exit 1
fi

echo "✅ Got token"

# Clients (Spark, pyiceberg) run on the host and reach MinIO via localhost;
# Polaris itself runs in Docker and uses the internal endpoint
echo ""
echo "📚 Creating Polaris catalog..."

STORAGE_CONFIG='{"storageType":"S3","endpoint":"http://localhost:9000","endpointInternal":"http://minio:9000","pathStyleAccess":true,"allowedLocations":["s3://warehouse"]}'
STORAGE_LOCATION='s3://warehouse'

PAYLOAD='{
   "catalog": {
     "name": "quickstart_catalog",
     "type": "INTERNAL",
     "readOnly": false,
     "properties": {
       "default-base-location": "'$STORAGE_LOCATION'"
     },
     "storageConfigInfo": '$STORAGE_CONFIG'
   }
 }'

curl -s -H "Authorization: Bearer ${TOKEN}" \
   -H 'Accept: application/json' \
   -H 'Content-Type: application/json' \
   -H "Polaris-Realm: POLARIS" \
   http://polaris:8181/api/management/v1/catalogs \
   -d "$PAYLOAD" | jq .

echo ""
echo "🔑 Granting CATALOG_MANAGE_CONTENT to catalog_admin..."
curl -s -H "Authorization: Bearer ${TOKEN}" \
  -H 'Content-Type: application/json' \
  -H "Polaris-Realm: POLARIS" \
  -X PUT \
  http://polaris:8181/api/management/v1/catalogs/quickstart_catalog/catalog-roles/catalog_admin/grants \
  -d '{"type":"catalog", "privilege":"CATALOG_MANAGE_CONTENT"}' | jq .

echo ""
echo "=========================================="
echo "✅ Bootstrap Complete!"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  - Catalog: quickstart_catalog"
echo "  - Storage: MinIO S3"
echo "  - Endpoint: http://localhost:9000 (clients), http://minio:9000 (Polaris)"
echo ""
echo "Credentials (Keycloak client, maps to Polaris principal root):"
echo "  Token endpoint: http://localhost:8080/realms/iceberg/protocol/openid-connect/token"
echo "  Client ID: client1"
echo "  Client Secret: s3cr3t"
echo ""
echo "Keycloak Console: http://localhost:8080"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "MinIO Console: http://localhost:9001"
echo "  Username: admin"
echo "  Password: password"
