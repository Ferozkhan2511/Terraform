# Provider + resource group

# Virtual Network (VNet) with 3 subnets: public, private, dmz

# Network Security Group (NSG) + separate NSG rules (one resource per rule)

# Route table + custom routes + subnet associations

# Public IP + NAT Gateway for private subnet outbound (so private VMs can reach internet)

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.0.0"
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "Feroz-RG"
  location = "West Europe"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = terra_vnet
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  
}

# Subnets
resource "azurerm_subnet" "public" {
  name                 = "subnet-public"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "private" {
  name                 = "subnet-private"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Network Security Group public
resource "azurerm_network_security_group" "nsg_public" {
  name                = "nsg-public"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  
}

#Network Security Group Private 
resource "azurerm_network_security_group" "nsg_private" {
  name                = "nsg-private"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# NSG Rules (one resource per rule) - inbound
resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "Allow-SSH"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  #source_address_prefix       = var.management_cidr
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_public.name
  description                 = "Allow SSH from management network"
}

resource "azurerm_network_security_rule" "allow_http" {
  name                        = "Allow-HTTP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_public.name
  description                 = "Allow HTTP"
}

resource "azurerm_network_security_rule" "allow_https" {
  name                        = "Allow-HTTPS"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_public.name
  description                 = "Allow HTTPS"
}

# NSG Rules - outbound (allow all outbound)
resource "azurerm_network_security_rule" "allow_out_all" {
  name                        = "Allow-Outbound-All"
  priority                    = 1000
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_public.name
  description                 = "Allow all outbound"
}

# Associate NSG to subnets (apply same NSG to public & dmz; leave private for NAT demo)
resource "azurerm_subnet_network_security_group_association" "public_assoc" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# resource "azurerm_subnet_network_security_group_association" "dmz_assoc" {
#   subnet_id                 = azurerm_subnet.dmz.id
#   network_security_group_id = azurerm_network_security_group.nsg.id
# }

# Route Table
resource "azurerm_route_table" "rt" {
  name                = "public-rt"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
 
}

# Associate route table to private subnet 
resource "azurerm_subnet_route_table_association" "private_rt_assoc" {
  subnet_id      = azurerm_subnet.private.id
  route_table_id = azurerm_route_table.rt.id
}

# Public IP for a VM (public subnet)
resource "azurerm_public_ip" "vm_public_ip" {
  name                = "public-vm-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NAT Gateway for private subnet outbound (so private subnet can reach internet without public IP on VMs)
resource "azurerm_public_ip" "nat_pip" {
  name                = "nat-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "nat" {
  name                = "nat"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard"

  public_ip_address_ids = [azurerm_public_ip.nat_pip.id]
}

# Associate NAT Gateway to private subnet
resource "azurerm_subnet_nat_gateway_association" "private_nat_assoc" {
  subnet_id      = azurerm_subnet.private.id
  nat_gateway_id = azurerm_nat_gateway.nat.id
}

# # Network Interface + Virtual Machine in Public Subnet (example)
# resource "azurerm_network_interface" "vm_nic" {
#   name                = "Vmnic"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name

#   ip_configuration {
#     name                          = "internal"
#     subnet_id                     = azurerm_subnet.public.id
#     private_ip_address_allocation = "Dynamic"
#     public_ip_address_id          = azurerm_public_ip.vm_public_ip.id
#   }
# }

# resource "azurerm_linux_virtual_machine" "vm" {
#   name                = var.vm_name
#   resource_group_name = azurerm_resource_group.rg.name
#   location            = azurerm_resource_group.rg.location
#   size                = var.vm_size
#   admin_username      = var.admin_username

#   admin_ssh_key {
#     username   = var.admin_username
#     public_key = file(var.ssh_public_key_path)
#   }

#   network_interface_ids = [azurerm_network_interface.vm_nic.id]

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#     name                 = "${var.vm_name}-osdisk"
#   }

#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "22_04-lts"
#     version   = "latest"
#   }
# }