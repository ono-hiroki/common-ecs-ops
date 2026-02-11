output "security_group_id" {
  value = aws_security_group.migrate_task.id
}

output "migrate_taskdef_yaml" {
  value = local.migrate_taskdef_yaml
}

output "container_definitions" {
  value = jsondecode(aws_ecs_task_definition.migrate.container_definitions)
}