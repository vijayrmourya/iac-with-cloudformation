output "stack_id" {
  description = "CloudFormation stack id"
  value       = aws_cloudformation_stack.vpc.id
}

output "stack_outputs" {
  description = "All CloudFormation stack outputs (map)"
  value       = aws_cloudformation_stack.vpc.outputs
}
