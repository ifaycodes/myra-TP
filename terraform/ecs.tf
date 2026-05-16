# ── ECS Cluster ──────────────────────────────────────────────
resource "aws_ecs_cluster" "myra_cluster" {
  name = "myra-cluster"
}

# ── IAM role ECS needs to pull images and run tasks ──────────
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ── Security group for ECS tasks ─────────────────────────────
resource "aws_security_group" "ecs_sg" {
  name   = "ecs-sg"
  vpc_id = module.myra_vpc.vpc_id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── Ingestion task ────────────────────────────────────────────
resource "aws_ecs_task_definition" "ingestion" {
  family                   = "ingestion"
  requires_compatibilities = ["EC2"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name  = "ingestion"
    image = var.ingestion_image
    portMappings = [{ containerPort = 8000 }]
    environment = [
      { name = "REDIS_HOST", value = aws_sqs_queue.ingest.url }
    ]
  }])
}

resource "aws_ecs_service" "ingestion" {
  name            = "ingestion"
  cluster         = aws_ecs_cluster.myra_cluster.id
  task_definition = aws_ecs_task_definition.ingestion.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets          = module.myra_vpc.public_subnets
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}

# ── Validation task ───────────────────────────────────────────
resource "aws_ecs_task_definition" "validation" {
  family                   = "validation"
  requires_compatibilities = ["EC2"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name  = "validation"
    image = var.validation_image
    environment = [
      { name = "INGEST_QUEUE_URL",    value = aws_sqs_queue.ingest.url },
      { name = "VALIDATED_QUEUE_URL", value = aws_sqs_queue.validated.url }
    ]
  }])
}

resource "aws_ecs_service" "validation" {
  name            = "validation"
  cluster         = aws_ecs_cluster.myra_cluster.id
  task_definition = aws_ecs_task_definition.validation.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets         = module.myra_vpc.private_subnets
    security_groups = [aws_security_group.ecs_sg.id]
  }
}

# ── Processing task ───────────────────────────────────────────
resource "aws_ecs_task_definition" "processing" {
  family                   = "processing"
  requires_compatibilities = ["EC2"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name  = "processing"
    image = var.processing_image
    environment = [
      { name = "VALIDATED_QUEUE_URL", value = aws_sqs_queue.validated.url },
      { name = "DB_HOST",             value = aws_db_instance.transactions.endpoint },
      { name = "DB_USER",             value = var.db_username },
      { name = "DB_PASSWORD",         value = var.db_password },
      { name = "DB_NAME",             value = "transactions" }
    ]
  }])
}

resource "aws_ecs_service" "processing" {
  name            = "processing"
  cluster         = aws_ecs_cluster.fintech.id
  task_definition = aws_ecs_task_definition.processing.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets         = module.myra_vpc.private_subnets
    security_groups = [aws_security_group.ecs_sg.id]
  }
}