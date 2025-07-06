#!/bin/bash

# Script to setup ADO variable groups from Terraform output
# Usage: ./setup-ado-variables.sh [terraform-output-file]

set -e

# Configuration
TERRAFORM_OUTPUT_FILE="${1:-terraform-output.json}"
ADO_ORGANIZATION="${ADO_ORGANIZATION:-https://dev.azure.com/yourorg}"
ADO_PROJECT="${ADO_PROJECT:-your-project}"
VARIABLE_GROUP_NAME="${VARIABLE_GROUP_NAME:-poc-deployment-vars}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] SETUP: $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if terraform output file exists
    if [ ! -f "$TERRAFORM_OUTPUT_FILE" ]; then
        error "Terraform output file not found: $TERRAFORM_OUTPUT_FILE"
        error "Generate it with: terraform output -json > $TERRAFORM_OUTPUT_FILE"
        exit 1
    fi
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        error "Azure CLI is not installed"
        error "Install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # Check if logged in to Azure CLI
    if ! az account show &> /dev/null; then
        error "Not logged in to Azure CLI"
        error "Login with: az login"
        exit 1
    fi
    
    # Check if Azure DevOps extension is installed
    if ! az extension show --name azure-devops &> /dev/null; then
        log "Installing Azure DevOps extension..."
        az extension add --name azure-devops
    fi
    
    success "Prerequisites check passed"
}

# Extract variables from Terraform output
extract_terraform_variables() {
    log "Extracting variables from Terraform output..."
    
    # Check if the JSON contains our expected output
    if ! jq -e '.ado_pipeline_variables.value' "$TERRAFORM_OUTPUT_FILE" > /dev/null 2>&1; then
        error "ado_pipeline_variables not found in Terraform output"
        error "Make sure you have the enhanced outputs.tf applied"
        exit 1
    fi
    
    # Extract the JSON string and parse it
    VARIABLES_JSON=$(jq -r '.ado_pipeline_variables.value' "$TERRAFORM_OUTPUT_FILE")
    
    if [ -z "$VARIABLES_JSON" ] || [ "$VARIABLES_JSON" = "null" ]; then
        error "No variables found in Terraform output"
        exit 1
    fi
    
    success "Variables extracted successfully"
}

# Create or update ADO variable group
setup_ado_variable_group() {
    log "Setting up ADO variable group: $VARIABLE_GROUP_NAME"
    
    # Set ADO organization context
    az devops configure --defaults organization="$ADO_ORGANIZATION" project="$ADO_PROJECT"
    
    # Check if variable group exists
    if az pipelines variable-group show --group-name "$VARIABLE_GROUP_NAME" &> /dev/null; then
        warning "Variable group '$VARIABLE_GROUP_NAME' already exists"
        read -p "Do you want to update it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Skipping variable group update"
            return
        fi
        
        # Update existing variable group
        log "Updating existing variable group..."
        GROUP_ID=$(az pipelines variable-group show --group-name "$VARIABLE_GROUP_NAME" --query id -o tsv)
        
        # Parse and add each variable
        echo "$VARIABLES_JSON" | jq -r 'to_entries[] | "\(.key)=\(.value)"' | while IFS='=' read -r key value; do
            log "Updating variable: $key"
            az pipelines variable-group variable update \
                --group-id "$GROUP_ID" \
                --name "$key" \
                --value "$value" > /dev/null 2>&1 || \
            az pipelines variable-group variable create \
                --group-id "$GROUP_ID" \
                --name "$key" \
                --value "$value" > /dev/null 2>&1
        done
        
        success "Variable group updated successfully"
    else
        # Create new variable group
        log "Creating new variable group..."
        
        # Start with creating the group
        GROUP_ID=$(az pipelines variable-group create \
            --name "$VARIABLE_GROUP_NAME" \
            --description "Deployment variables from Terraform - Auto-generated" \
            --variables dummy=temp \
            --query id -o tsv)
        
        # Remove dummy variable
        az pipelines variable-group variable delete \
            --group-id "$GROUP_ID" \
            --name "dummy" --yes > /dev/null 2>&1
        
        # Add all variables from Terraform output
        echo "$VARIABLES_JSON" | jq -r 'to_entries[] | "\(.key)=\(.value)"' | while IFS='=' read -r key value; do
            log "Adding variable: $key"
            az pipelines variable-group variable create \
                --group-id "$GROUP_ID" \
                --name "$key" \
                --value "$value" > /dev/null 2>&1
        done
        
        success "Variable group created successfully"
    fi
}

# Display setup instructions
display_instructions() {
    log "Setup Instructions:"
    echo
    echo "1. Variable group '$VARIABLE_GROUP_NAME' has been created/updated in ADO"
    echo "2. To use in your pipeline, add this to your azure-pipelines.yml:"
    echo
    echo "   variables:"
    echo "   - group: '$VARIABLE_GROUP_NAME'"
    echo
    echo "3. Available variables in your pipeline:"
    echo "$VARIABLES_JSON" | jq -r 'keys[]' | while read -r key; do
        echo "   - \$(${key})"
    done
    echo
    echo "4. Example usage in pipeline:"
    echo "   - script: |"
    echo "       echo \"Deploying to: \$(TRUSTED_SCRUB_IP)\""
    echo "       echo \"Using ECR: \$(ECR_REGISTRY)\""
    echo
    success "Setup completed successfully!"
}

# Generate manual setup file
generate_manual_setup() {
    log "Generating manual setup file..."
    
    cat > "ado-variables-manual.txt" << EOF
# ADO Variable Group Setup - Manual Instructions
# Variable Group Name: $VARIABLE_GROUP_NAME
# Generated: $(date)

# Variables to add in Azure DevOps:
# Go to: $ADO_ORGANIZATION/$ADO_PROJECT/_library?itemType=VariableGroups

EOF
    
    echo "$VARIABLES_JSON" | jq -r 'to_entries[] | "\(.key)=\(.value)"' >> "ado-variables-manual.txt"
    
    success "Manual setup file generated: ado-variables-manual.txt"
}

# Main execution
main() {
    log "Starting ADO variable group setup..."
    log "Organization: $ADO_ORGANIZATION"
    log "Project: $ADO_PROJECT"
    log "Variable Group: $VARIABLE_GROUP_NAME"
    log "Terraform Output: $TERRAFORM_OUTPUT_FILE"
    
    check_prerequisites
    extract_terraform_variables
    
    # Try automated setup first
    if setup_ado_variable_group; then
        display_instructions
    else
        warning "Automated setup failed, generating manual setup file..."
        generate_manual_setup
    fi
}

# Help function
show_help() {
    echo "Usage: $0 [terraform-output-file]"
    echo
    echo "Setup Azure DevOps variable groups from Terraform output"
    echo
    echo "Arguments:"
    echo "  terraform-output-file  JSON file with terraform output (default: terraform-output.json)"
    echo
    echo "Environment Variables:"
    echo "  ADO_ORGANIZATION      Azure DevOps organization URL"
    echo "  ADO_PROJECT          Azure DevOps project name"
    echo "  VARIABLE_GROUP_NAME  Name for the variable group (default: poc-deployment-vars)"
    echo
    echo "Examples:"
    echo "  $0                                    # Use default terraform-output.json"
    echo "  $0 my-terraform-output.json          # Use custom output file"
    echo "  ADO_ORGANIZATION=https://dev.azure.com/myorg ADO_PROJECT=myproject $0"
    echo
    echo "Prerequisites:"
    echo "  - Azure CLI installed and logged in"
    echo "  - Terraform output file with ado_pipeline_variables"
    echo "  - Permissions to create/update variable groups in ADO"
}

# Handle arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac