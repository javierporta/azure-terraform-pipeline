# Set this in the app settings: AzureAd_ClientId.
output "azure_ad_client_id" {
  value = azuread_application.app_registration.application_id
}
