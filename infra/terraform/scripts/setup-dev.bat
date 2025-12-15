@echo off
echo Setting up Terraform for DEV environment...

cd /d "%~dp0..\environments\dev"

echo Initializing Terraform with backend...
terraform init -backend-config=backend.hcl

echo Planning changes...
terraform plan

echo.
echo To apply changes, run:
echo terraform apply

pause