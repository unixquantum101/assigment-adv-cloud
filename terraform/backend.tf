# Remote state in S3 (with native locking). The bucket name is NOT hard-coded;
# pass it at init time:
#
#   terraform init -backend-config="bucket=<your-state-bucket>" -backend-config="region=<region>"
#
# See README "Terraform" section for creating the bucket once.
# To use local state instead, delete this file (state files are .gitignore'd).
terraform {
  backend "s3" {
    key          = "cloud-computing-project/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
