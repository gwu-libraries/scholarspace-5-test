#!/bin/bash

# Change directory to the folder
cd /opt/scholarspace/scholarspace-5-test/
# Stash any local changes
git stash
# Checkout main branch if not already on it
git checkout main
# Pull any changes  
git pull
# Stop and remove containers

cat > docker-compose.yml << EOF
include:
  - docker-compose-prod.yml
EOF

docker compose stop
echo "Restarting Docker containers"
docker compose up -d