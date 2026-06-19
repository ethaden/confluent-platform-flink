if [ -z ${NEXUS_ADMIN_PASS} ]; then
  echo "Please set variable NEXUS_ADMIN_PASS before running this script"
  echo "export NEXUS_ADMIN_PASS=YOUR_NEXUS_ADMIN_PASSWORD"
  exit 1
fi

# docker.io
curl -X POST \
  "http://localhost:18081/service/rest/v1/repositories/docker/proxy" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -u "admin:$NEXUS_ADMIN_PASS" \
  -d '{
    "name": "docker-hub-proxy",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true
    },
    "docker": {
      "v1Enabled": false,
      "forceBasicAuth": false,
      "httpPort": 15001,
      "httpsPort": null,
      "allowAnonymous": true
    },
    "proxy": {
      "remoteUrl": "https://registry-1.docker.io",
      "contentMaxAge": 1440,
      "metadataMaxAge": 1440
    },
    "dockerProxy": {
      "indexType": "HUB"
    },
    "httpClient": {
      "autoBlock": true,
      "blocked": false,
      "connection": {
        "retries": 2,
        "timeout": 60,
        "enableCircularRedirects": true,
        "enableCookies": true,
        "useTrustStore": false
      }
    },
    "negativeCache": {
      "enabled": true,
      "timeToLive": 1440
    }
  }'

# quay.io
curl -X POST \
  "http://localhost:18081/service/rest/v1/repositories/docker/proxy" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -u "admin:$NEXUS_ADMIN_PASS" \
  -d '{
    "name": "quay-proxy",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true
    },
    "docker": {
      "v1Enabled": false,
      "forceBasicAuth": false,
      "httpPort": 15002,
      "httpsPort": null,
      "allowAnonymous": true
    },
    "proxy": {
      "remoteUrl": "https://quay.io",
      "contentMaxAge": 1440,
      "metadataMaxAge": 1440
    },
    "dockerProxy": {
      "indexType": "CUSTOM",
      "indexUrl": "https://quay.io"
    },
    "httpClient": {
      "autoBlock": true,
      "blocked": false,
      "connection": {
        "retries": 2,
        "timeout": 60,
        "enableCircularRedirects": true,
        "enableCookies": true,
        "useTrustStore": false
      }
    },
    "negativeCache": {
      "enabled": true,
      "timeToLive": 1440
    }
  }'

# registry.k8s.io
curl -X POST \
  "http://localhost:18081/service/rest/v1/repositories/docker/proxy" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -u "admin:$NEXUS_ADMIN_PASS" \
  -d '{
    "name": "k8s-proxy",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true
    },
    "docker": {
      "v1Enabled": false,
      "forceBasicAuth": false,
      "httpPort": 15003,
      "httpsPort": null,
      "allowAnonymous": true
    },
    "proxy": {
      "remoteUrl": "https://registry.k8s.io",
      "contentMaxAge": 1440,
      "metadataMaxAge": 1440
    },
    "dockerProxy": {
      "indexType": "CUSTOM",
      "indexUrl": "https://registry.k8s.io"
    },
    "httpClient": {
      "autoBlock": true,
      "blocked": false,
      "connection": {
        "retries": 2,
        "timeout": 60,
        "enableCircularRedirects": true,
        "enableCookies": true,
        "useTrustStore": false
      }
    },
    "negativeCache": {
      "enabled": true,
      "timeToLive": 1440
    }
  }'
