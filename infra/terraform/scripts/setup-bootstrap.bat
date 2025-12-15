@echo off
echo Setting up IAM roles using bootstrap admin...

cd /d "%~dp0..\environments\bootstrap"

echo Copy terraform.tfvars.example to terraform.tfvars and update values
echo.

if not exist terraform.tfvars (
    echo ERROR: terraform.tfvars not found
    echo Please copy terraform.tfvars.example to terraform.tfvars and update values
    pause
    exit /b 1
)

echo Initializing Terraform...
terraform init

echo Planning IAM roles creation...
terraform plan

echo.
echo To create IAM roles, run:
echo terraform apply

pause