resource "aws_db_subnet_group" "database" {
  name       = "listener"
  subnet_ids = data.terraform_remote_state.cluster.outputs.node_subnet
}

resource "aws_db_instance" "database" {
  allocated_storage      = 5
  engine                 = "mariadb"
  instance_class         = "db.t2.micro"
  name                   = "listener"
  username               = var.database_user
  password               = var.database_password
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.database.id]
  db_subnet_group_name   = aws_db_subnet_group.database.name
}
