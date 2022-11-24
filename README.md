# IaC & Pipeline for a classic Web Application in Azure


## Description
Example of a Terraform template to create the following resources:

- Resource Group
- App Registration (using enterprise application and some app roles)
- App Service Plan
- App Service
- SQL Server Instance (with a random generated password, and DB firewall allowing azure resources)
- SQL Server Database
- Key Vault (and permissions assigned)

### Flow

![IaC Flow Image](https://github.com/javierporta/azure-terraform-pipeline/blob/main/images/IaC-diagram.png?raw=true)


Then a yaml pipeline [build/pipelines/iac-pipeline.yml] is used to run the *validate*, *init*, *plan*, and apply commands of Terraform in AzureDevOps with different values depending on the environment usign a given service connection, so any user with permission can run the IaC without the need of having Terrafrom in his/her local environment.

Terraform state is stored in an Azure Blob container. There is a way to create this on the pipeline but it is not working properly, so I strongly suggest to create that in advance.

## Requisites
- Terraform (if running it locally)
- Azure DevOps (if using a pipeline)




