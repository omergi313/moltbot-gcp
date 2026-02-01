# GCS Remote State Configuration
#
# Before running terraform init, create the bucket:
#   gsutil mb -p <PROJECT_ID> -l <REGION> gs://<BUCKET_NAME>
#   gsutil versioning set on gs://<BUCKET_NAME>

terraform {
  backend "gcs" {
    bucket = "openclaw-terraform-state"
    prefix = "terraform/state"
  }
}
