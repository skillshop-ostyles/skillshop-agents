resource "aws_s3_bucket" "assets" {
  bucket = "myapp-assets-production"
}

resource "aws_db_instance" "main" {
  identifier = "myapp-production"
  engine     = "postgres"
  instance_class = "db.r5.large"

  backup_retention_period = 30
  backup_window = "03:00-04:00"
}

resource "aws_dynamodb_table" "sessions" {
  name     = "myapp-sessions"
  hash_key = "id"

  attribute {
    name = "id"
    type = "S"
  }
}
