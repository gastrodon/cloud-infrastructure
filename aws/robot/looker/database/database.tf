resource "aws_db_subnet_group" "database" {
  name       = "looker"
  subnet_ids = data.terraform_remote_state.cluster.outputs.node_subnet
}

resource "aws_db_instance" "database" {
  allocated_storage      = 250
  engine                 = "mariadb"
  instance_class         = "db.t3.medium"
  name                   = "looker"
  username               = var.database_user
  password               = var.database_password
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.database.id]
  db_subnet_group_name   = aws_db_subnet_group.database.name

  publicly_accessible = true
}
