# Terraform diagnostics to find why routes aren't being created

echo "=== 1. Check Terraform State for Route Resources ==="
terraform state list | grep aws_route

echo -e "\n=== 2. Check VPC Module Outputs ==="
terraform state show 'module.untrusted_vpc_streaming_ingress.aws_route_table.public[0]' 2>/dev/null | grep "id\s*=" || echo "❌ Public route table not found"
terraform state show 'module.untrusted_vpc_streaming_ingress.aws_route_table.private[0]' 2>/dev/null | grep "id\s*=" || echo "❌ Private route table not found"

echo -e "\n=== 3. Check if Route Resources Exist in Plan ==="
terraform plan -target=aws_route.untrusted_ingress_public_to_devops -target=aws_route.untrusted_ingress_private_to_devops

echo -e "\n=== 4. Check VPC Module Route Table IDs ==="
# Check if we can get the actual route table IDs from Terraform
terraform state show 'module.untrusted_vpc_streaming_ingress' 2>/dev/null | grep -E "(public_route_table_id|private_route_table_id)" || echo "❌ Route table IDs not found in state"

echo -e "\n=== 5. Check Specific Route State ==="
terraform state show 'aws_route.untrusted_ingress_public_to_devops' 2>/dev/null || echo "❌ Public ingress route not in state"
terraform state show 'aws_route.untrusted_ingress_private_to_devops' 2>/dev/null || echo "❌ Private ingress route not in state"

echo -e "\n=== 6. Verify Module Outputs ==="
terraform output -json | jq -r '
  if .module_outputs then
    .module_outputs
  else
    "No module outputs found"
  end
'

echo -e "\n=== 7. Check All VPC Module Resources ==="
terraform state list | grep module.*vpc.*route_table
