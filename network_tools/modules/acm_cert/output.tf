output "cert" {
  value = aws_acm_certificate.cert.arn
}

output "certificate_validation" {
  value = aws_acm_certificate_validation.cert_validation
}
