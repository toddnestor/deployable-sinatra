output "subdomain" {
  value = "${var.subdomain}"
}

output "name" {
  value = "${var.name}"
}

output "alb_dns" {
  value = "${coalesce(module.alb-public.dns_name, module.alb-internal.dns_name)}"
}
