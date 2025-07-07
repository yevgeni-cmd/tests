#!/bin/bash

# Immediate fix script for SSH access to ingress host
# This will add the missing routes that Terraform should be managing

set -e

AWS_REGION="il-central-1"
AWS_PROFILE="728951503198_SystemAdministrator-8H"

echo "=== Finding Missing Routes for SSH Access ==="

# Get the untrusted TGW ID
UNTRUSTED_TGW_ID=$(aws ec2 describe-transit-gateways \
  --filters "Name=tag:Name,Values=*untrusted*" \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'TransitGateways[0].TransitGatewayId' \
  --output text)

echo "Untrusted TGW ID: $UNTRUSTED_TGW_ID"

# Get the devops VPC CIDR (where VPN clients NAT through)
DEVOPS_VPC_CIDR="172.19.24.0/24"

# Get all route tables in the untrusted streaming ingress VPC
INGRESS_VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=*untrusted-streaming-ingress*" \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'Vpcs[0].VpcId' \
  --output text)

echo "Ingress VPC ID: $INGRESS_VPC_ID"

# Get route tables for this VPC
ROUTE_TABLES=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$INGRESS_VPC_ID" \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'RouteTables[*].RouteTableId' \
  --output text)

echo "Route Tables in Ingress VPC: $ROUTE_TABLES"

# Add missing routes to each route table
for RT_ID in $ROUTE_TABLES; do
  echo "=== Checking Route Table: $RT_ID ==="
  
  # Check if route already exists
  EXISTING_ROUTE=$(aws ec2 describe-route-tables \
    --route-table-ids $RT_ID \
    --region $AWS_REGION \
    --profile $AWS_PROFILE \
    --query "RouteTables[0].Routes[?DestinationCidrBlock=='$DEVOPS_VPC_CIDR'].DestinationCidrBlock" \
    --output text)
  
  if [ -z "$EXISTING_ROUTE" ]; then
    echo "Adding route to devops VPC ($DEVOPS_VPC_CIDR) via TGW ($UNTRUSTED_TGW_ID)"
    aws ec2 create-route \
      --route-table-id $RT_ID \
      --destination-cidr-block $DEVOPS_VPC_CIDR \
      --transit-gateway-id $UNTRUSTED_TGW_ID \
      --region $AWS_REGION \
      --profile $AWS_PROFILE
    echo "✅ Route added successfully"
  else
    echo "✅ Route already exists"
  fi
done

# Also check scrub VPC route tables (for completeness)
echo "=== Checking Scrub VPC Route Tables ==="
SCRUB_VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=*untrusted-streaming-scrub*" \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'Vpcs[0].VpcId' \
  --output text)

echo "Scrub VPC ID: $SCRUB_VPC_ID"

SCRUB_ROUTE_TABLES=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$SCRUB_VPC_ID" \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query 'RouteTables[*].RouteTableId' \
  --output text)

for RT_ID in $SCRUB_ROUTE_TABLES; do
  echo "=== Checking Scrub Route Table: $RT_ID ==="
  
  EXISTING_ROUTE=$(aws ec2 describe-route-tables \
    --route-table-ids $RT_ID \
    --region $AWS_REGION \
    --profile $AWS_PROFILE \
    --query "RouteTables[0].Routes[?DestinationCidrBlock=='$DEVOPS_VPC_CIDR'].DestinationCidrBlock" \
    --output text)
  
  if [ -z "$EXISTING_ROUTE" ]; then
    echo "Adding route to devops VPC ($DEVOPS_VPC_CIDR) via TGW ($UNTRUSTED_TGW_ID)"
    aws ec2 create-route \
      --route-table-id $RT_ID \
      --destination-cidr-block $DEVOPS_VPC_CIDR \
      --transit-gateway-id $UNTRUSTED_TGW_ID \
      --region $AWS_REGION \
      --profile $AWS_PROFILE
    echo "✅ Route added successfully"
  else
    echo "✅ Route already exists"
  fi
done

echo "=== Fix complete! Try SSH again ==="
