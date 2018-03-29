
output "instance_id" {
  value = "${aws_instance.application_instance.id}"
}

output "service_name" {
  value = "${aws_vpc_endpoint_service.application_vpc_endpoint_service.service_name}"
}
