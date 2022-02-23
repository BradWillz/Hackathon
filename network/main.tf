terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.86.0"
    }
  }
    backend "azurerm" {
        resource_group_name  = "team4-hub-vnet-rg"
        storage_account_name = "team4sasamsmith"
        container_name       = "content"
        key                  = "terraform.tfstate"
    }
}


provider "azurerm" {
  features {}
  alias           = "hub"
  subscription_id = var.hub_subscription_id
}

### Hub Resources ###
## Hub Network Resources ##
# Hub Network Resource Group #
resource "azurerm_resource_group" "hub_vnet" {
  provider = azurerm.hub
  name     = format("%s-rg", var.hub_vnet_name)
  location = var.location

  tags = local.tags
}

resource "azurerm_storage_account" "storage" {
  provider                 = azurerm.hub
  name                     = "team4sasamsmith"
  resource_group_name      = azurerm_resource_group.hub_vnet.name
  location                 = azurerm_resource_group.hub_vnet.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags       = local.tags
  depends_on = [azurerm_resource_group.hub_vnet]
}

resource "azurerm_storage_container" "storage" {
  provider              = azurerm.hub
  name                  = "content"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"

  depends_on = [azurerm_storage_account.storage]

}

output "storage_account_primary_access_key" {
  value = azurerm_storage_account.storage.primary_access_key
  sensitive = true
}

# Hub VNet #
resource "azurerm_virtual_network" "hub_vnet" {
  provider            = azurerm.hub
  name                = var.hub_vnet_name
  location            = azurerm_resource_group.hub_vnet.location
  resource_group_name = azurerm_resource_group.hub_vnet.name
  address_space       = var.hub_vnet_address_space

  depends_on = [azurerm_resource_group.hub_vnet]

  tags = local.tags
}

# Hub gatewaysubnet Subnet #
resource "azurerm_subnet" "hub_vnet1" {
  provider             = azurerm.hub
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub_vnet.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = var.hub_vnet_subnet1

  depends_on = [azurerm_virtual_network.hub_vnet]
}

# Hub jumpbox Subnet #
resource "azurerm_subnet" "hub_vnet2" {
  provider             = azurerm.hub
  name                 = "mgmt-sn"
  resource_group_name  = azurerm_resource_group.hub_vnet.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = var.hub_vnet_subnet2

  depends_on = [azurerm_virtual_network.hub_vnet]
}

# Hub AzureBastionSubnet Subnet #
resource "azurerm_subnet" "hub_vnet6" {
  provider             = azurerm.hub
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub_vnet.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = var.hub_vnet_subnet6

  depends_on = [azurerm_virtual_network.hub_vnet]
}

# Hub Peering to MGMT #
resource "azurerm_virtual_network_peering" "hub_vnet1" {
  provider                     = azurerm.hub
  name                         = format("%s-to-%s", var.hub_vnet_name, var.mgmt_vnet_name)
  resource_group_name          = azurerm_resource_group.hub_vnet.name
  virtual_network_name         = azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.mgmt_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true

  depends_on = [azurerm_virtual_network.hub_vnet, azurerm_virtual_network.mgmt_vnet]
}

# Hub Route Table #
resource "azurerm_route_table" "hub_vnet" {
  provider            = azurerm.hub
  name                = format("%s-rt", var.hub_vnet_name)
  resource_group_name = azurerm_resource_group.hub_vnet.name
  location            = azurerm_resource_group.hub_vnet.location

  depends_on = [azurerm_resource_group.hub_vnet]

  tags = local.tags
}

# APP attach Route Table to mgmt-sn #
resource "azurerm_subnet_route_table_association" "hub_vnet" {
  provider       = azurerm.hub
  subnet_id      = azurerm_subnet.hub_vnet2.id
  route_table_id = azurerm_route_table.hub_vnet.id

  depends_on = [azurerm_route_table.hub_vnet, azurerm_subnet.hub_vnet2]
}

# Hub NSG #
resource "azurerm_network_security_group" "hub_vnet" {
  provider            = azurerm.hub
  name                = format("%s-nsg", var.hub_vnet_name)
  resource_group_name = azurerm_resource_group.hub_vnet.name
  location            = azurerm_resource_group.hub_vnet.location

  security_rule {
    name                         = "AllowInternalToAzure"
    priority                     = 1000
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "*"
    source_port_range            = "*"
    destination_port_range       = "*"
    source_address_prefixes      = ["192.168.0.0/16", "172.16.0.0/12", "10.0.0.0/8"]
    destination_address_prefixes = var.hub_vnet_address_space
  }

  depends_on = [azurerm_resource_group.hub_vnet]

  tags = local.tags
}

# APP attach NSG to mgmt-sn #
resource "azurerm_subnet_network_security_group_association" "hub_vnet" {
  provider                  = azurerm.hub
  subnet_id                 = azurerm_subnet.hub_vnet2.id
  network_security_group_id = azurerm_network_security_group.hub_vnet.id

  depends_on = [azurerm_network_security_group.hub_vnet, azurerm_subnet.hub_vnet1]
}

# Hub Bastion Public IP #
resource "azurerm_public_ip" "bastion" {
  provider            = azurerm.hub
  name                = format("%s-pip", var.hub_bastion_name)
  location            = azurerm_resource_group.hub_vnet.location
  resource_group_name = azurerm_resource_group.hub_vnet.name
  allocation_method   = "Static"
  sku                 = "Standard"

  depends_on = [azurerm_resource_group.hub_vnet]

  tags = local.tags
}

# Hub Bastion #
resource "azurerm_bastion_host" "bastion" {
  provider            = azurerm.hub
  name                = var.hub_bastion_name
  location            = azurerm_resource_group.hub_vnet.location
  resource_group_name = azurerm_resource_group.hub_vnet.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.hub_vnet6.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  depends_on = [azurerm_resource_group.hub_vnet, azurerm_public_ip.bastion, azurerm_subnet.hub_vnet6]

  tags = local.tags
}


## Management VM Resources ##
# Management VM NIC  #
resource "azurerm_network_interface" "mgmt_vm" {
  provider            = azurerm.hub
  name                = format("%s01-nic", var.mgmt_vm_name)
  location            = azurerm_resource_group.hub_vnet.location
  resource_group_name = azurerm_resource_group.hub_vnet.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.hub_vnet2.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_resource_group.hub_vnet, azurerm_subnet.hub_vnet2]

  tags = local.tags
}

# Management VM #
resource "azurerm_windows_virtual_machine" "mgmt_vm" {
  provider            = azurerm.hub
  name                = format("%s01", var.mgmt_vm_name)
  resource_group_name = azurerm_resource_group.hub_vnet.name
  location            = azurerm_resource_group.hub_vnet.location
  size                = "Standard_D2s_v4"
  admin_username      = "adminuser"
  admin_password      = "123changeme!@password"
  timezone            = "GMT Standard Time"
  network_interface_ids = [
    azurerm_network_interface.mgmt_vm.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  depends_on = [azurerm_resource_group.hub_vnet, azurerm_subnet.hub_vnet2]

  tags = local.tags
}


# VPNGATEWAY
resource "azurerm_public_ip" "hub_vpngw" {
  provider            = azurerm.hub
  name                = "vpngw-pip"
  location            = azurerm_resource_group.hub_vnet.location
  resource_group_name = azurerm_resource_group.hub_vnet.name

  allocation_method = "Dynamic"

  depends_on = [azurerm_resource_group.hub_vnet, azurerm_subnet.hub_vnet1]

  tags = local.tags
}

resource "azurerm_virtual_network_gateway" "hub_vpngw" {
  provider            = azurerm.hub
  name                = "team4-vpngw"
  location            = azurerm_resource_group.hub_vnet.location
  resource_group_name = azurerm_resource_group.hub_vnet.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "vpngw1"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.hub_vpngw.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.hub_vnet1.id
  }

  depends_on = [azurerm_resource_group.hub_vnet, azurerm_subnet.hub_vnet1, azurerm_public_ip.hub_vpngw]

  tags = local.tags

}

resource "azurerm_local_network_gateway" "hub_vpngw" {
  provider            = azurerm.hub
  name                = "team4-localgw"
  resource_group_name = azurerm_resource_group.hub_vnet.name
  location            = azurerm_resource_group.hub_vnet.location
  gateway_address     = "52.210.78.122"
  address_space       = ["172.15.0.0/16"]

  depends_on = [azurerm_resource_group.hub_vnet, azurerm_subnet.hub_vnet1, azurerm_public_ip.hub_vpngw]

  tags = local.tags
}

resource "azurerm_virtual_network_gateway_connection" "hub_vpngw" {
  provider            = azurerm.hub
  name                = "hub_vpngw-conn"
  location            = azurerm_resource_group.hub_vnet.location
  resource_group_name = azurerm_resource_group.hub_vnet.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.hub_vpngw.id
  local_network_gateway_id   = azurerm_local_network_gateway.hub_vpngw.id

  shared_key = "gOrI.vagR3jGOcTKY6JApuOsTuPdeFGd"

  depends_on = [azurerm_resource_group.hub_vnet, azurerm_subnet.hub_vnet1, azurerm_public_ip.hub_vpngw, azurerm_local_network_gateway.hub_vpngw, azurerm_virtual_network_gateway.hub_vpngw]

  tags = local.tags
}

### APP Resources ###
## APP Network Resources ##
# APP Network Resource Group #
resource "azurerm_resource_group" "mgmt_vnet" {
  provider = azurerm.hub
  name     = format("%s-rg", var.mgmt_vnet_name)
  location = var.location

  tags = local.tags
}

# APP VNet #
resource "azurerm_virtual_network" "mgmt_vnet" {
  provider            = azurerm.hub
  name                = var.mgmt_vnet_name
  location            = azurerm_resource_group.mgmt_vnet.location
  resource_group_name = azurerm_resource_group.mgmt_vnet.name
  address_space       = var.mgmt_vnet_address_space

  depends_on = [azurerm_resource_group.mgmt_vnet]

  tags = local.tags
}

# APP mgmt-sn Subnet #
resource "azurerm_subnet" "mgmt_vnet1" {
  provider             = azurerm.hub
  name                 = "app-sn"
  resource_group_name  = azurerm_resource_group.mgmt_vnet.name
  virtual_network_name = azurerm_virtual_network.mgmt_vnet.name
  address_prefixes     = var.mgmt_vnet_subnet1
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "acidelegationservice"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }

  depends_on = [azurerm_virtual_network.mgmt_vnet]
}

#################
# APP Peering to Hub #
resource "azurerm_virtual_network_peering" "mgmt_vnet1" {
  provider                     = azurerm.hub
  name                         = format("%s-to-%s", var.mgmt_vnet_name, var.hub_vnet_name)
  resource_group_name          = azurerm_resource_group.mgmt_vnet.name
  virtual_network_name         = azurerm_virtual_network.mgmt_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.hub_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true

  depends_on = [azurerm_virtual_network.mgmt_vnet, azurerm_virtual_network.hub_vnet]
}

# APP Route Table #
resource "azurerm_route_table" "mgmt_vnet" {
  provider            = azurerm.hub
  name                = format("%s-rt", var.mgmt_vnet_name)
  resource_group_name = azurerm_resource_group.mgmt_vnet.name
  location            = azurerm_resource_group.mgmt_vnet.location

  tags = local.tags

  depends_on = [azurerm_resource_group.mgmt_vnet]
}

# APP attach Route Table to mgmt-sn #
resource "azurerm_subnet_route_table_association" "mgmt_vnet1" {
  provider       = azurerm.hub
  subnet_id      = azurerm_subnet.mgmt_vnet1.id
  route_table_id = azurerm_route_table.mgmt_vnet.id

  depends_on = [azurerm_route_table.mgmt_vnet, azurerm_subnet.mgmt_vnet1]
}

# APP NSG #
resource "azurerm_network_security_group" "mgmt_vnet" {
  provider            = azurerm.hub
  name                = format("%s-nsg", var.mgmt_vnet_name)
  resource_group_name = azurerm_resource_group.mgmt_vnet.name
  location            = azurerm_resource_group.mgmt_vnet.location

  security_rule {
    name                         = "AllowInternalToAzure"
    priority                     = 1000
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "*"
    source_port_range            = "*"
    destination_port_range       = "*"
    source_address_prefixes      = ["192.168.0.0/16", "172.16.0.0/12", "10.0.0.0/8"]
    destination_address_prefixes = var.mgmt_vnet_address_space
  }

  depends_on = [azurerm_resource_group.mgmt_vnet]

  tags = local.tags
}

# APP attach NSG to mgmt-sn #
resource "azurerm_subnet_network_security_group_association" "mgmt_vnet1" {
  provider                  = azurerm.hub
  subnet_id                 = azurerm_subnet.mgmt_vnet1.id
  network_security_group_id = azurerm_network_security_group.mgmt_vnet.id

  depends_on = [azurerm_network_security_group.mgmt_vnet, azurerm_subnet.mgmt_vnet1]
}