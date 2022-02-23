terraform {
  required_version = ">= 1.0.1"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      /*version = "=2.55.0"*/
    }
    azuread = {
      source = "hashicorp/azuread"
      /*version = "=1.4.0"*/
    }
  }
}

# Providers
provider "azuread" {
  tenant_id = var.tenant_id
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

}


#####Data Import of VNets#######
data "azurerm_virtual_network" "vnet" {
  name                = "team4-app-vnet"
  resource_group_name = "team4-app-vnet-rg"
}

data "azurerm_subnet" "vnet" {
  name                 = "app-sn"
  virtual_network_name = "team4-app-vnet"
  resource_group_name  = "team4-app-vnet-rg"
}

####### ACR DEPLOYMENT ##########
resource "azurerm_container_registry" "acr" {
  name                = lower(replace("${var.resource_prefix}-${var.location_short}-${var.environment_short}-ACR", "/[-_]/", ""))
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  sku                 = "Standard"
  admin_enabled       = true

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}


resource "null_resource" "import_image_hello_world" {
  //provisioner "local-exec" {
  //  command = "az acr import --name ${azurerm_container_registry.acr.name} --source docker.io/library/hello-world:latest --image hello-world:latest"
  //}
  provisioner "local-exec" {
    command = "az acr login --name ${azurerm_container_registry.acr.name}"
  }
  provisioner "local-exec" {
    command = "docker pull mcr.microsoft.com/dotnet/core/samples:aspnetapp"
  }
  provisioner "local-exec" {
    command = "docker tag mcr.microsoft.com/dotnet/core/samples:aspnetapp ${azurerm_container_registry.acr.name}.azurecr.io/aspnet:v1"
  }
  provisioner "local-exec" {
    command = "docker push ${azurerm_container_registry.acr.name}.azurecr.io/aspnet:v1"
  }
}

################## ACI DEPLOYMENT ###############
resource "azurerm_resource_group" "app" {
  name     = "${var.resource_prefix}-${var.location_short}-${var.environment_short}-APP-RG"
  location = var.location

  tags = local.tags
}


# Internal Networking NIC

resource "azurerm_network_profile" "aci" {
  name                = "${var.resource_prefix}-${var.location_short}-${var.environment_short}-ACI-NP"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name

  container_network_interface {
    name = "${var.resource_prefix}-${var.location_short}-${var.environment_short}-ACI-NIC"

    ip_configuration {
      name      = "aciipconfig"
      subnet_id = data.azurerm_subnet.vnet.id
    }
  }
}

# ACI Container
resource "azurerm_container_group" "aci" {
  name                = "${var.resource_prefix}-${var.location_short}-${var.environment_short}-ACI"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  ip_address_type     = "Private"
  network_profile_id  = azurerm_network_profile.aci.id
  os_type             = "Linux"

  image_registry_credential {
    username = azurerm_container_registry.acr.admin_username
    password = azurerm_container_registry.acr.admin_password
    server   = azurerm_container_registry.acr.login_server
  }

  container {
    name   = "aspnet"
    image  = "${azurerm_container_registry.acr.name}.azurecr.io/aspnet:v1" //"${azurerm_container_registry.acr.name}.azurecr.io/hello-world:latest" //"mcr.microsoft.com/azuredocs/aci-helloworld:latest" //"${azurerm_container_registry.acr.name}.azurecr.io/hello-world:latest"
    cpu    = "1"
    memory = "1.5"

    ports {
      port     = 80
      protocol = "TCP"
    }

  }


  tags = local.tags
  depends_on = [
    null_resource.import_image_hello_world
  ]
}