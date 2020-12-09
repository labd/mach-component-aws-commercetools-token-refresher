output "name" {
  value = aws_secretsmanager_secret.ct_access_token.name
}

# In case older implementation may still require the secret that has been created
output "client_id" {
  value = commercetools_api_client.main.id
}

output "client_secret" {
  value = commercetools_api_client.main.secret
}