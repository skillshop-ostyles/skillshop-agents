resource "aws_s3_bucket" "uploads" {
  bucket = "myapp-uploads-production"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_db_instance" "main" {
  identifier = "myapp-production"
  engine     = "postgres"
  instance_class = "db.r5.large"
  allocated_storage = 100
  storage_encrypted = true
}
