output "alb_dns_name" {
  description = "The DNS name of the load balancer."
  value       = var.enable_asg ? module.alb.this_lb_dns_name : ""
}
