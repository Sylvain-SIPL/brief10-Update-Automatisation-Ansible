terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}


provider "azurerm" {
  features {}
  subscription_id = "ec907711-acd7-4191-9983-9577afbe3ce1"
}

data "azurerm_resource_group" "rg" {
  name = "Ansible-grp-Syl"
}

###### describe Vnet ###########

resource "azurerm_virtual_network" "vnetsrv" {
  name                = "vnet-server"
  address_space       = ["192.168.28.0/22"]
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

###### describe Subnet #############

resource "azurerm_subnet" "subnetsrv" {
  name                 = "subnet-server"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnetsrv.name
  address_prefixes     = ["192.168.30.0/24"]
}

####### describe serveurs NIC nginx ##########

resource "azurerm_public_ip" "pub-nginx-ip" {
  count               = 2
  name                = "publicip-nginx-srv-${count.index + 1}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}


resource "azurerm_network_interface" "nics-nginx-srv" {
  count               = 2
  name                = "nics-nginx-srv-${count.index + 1}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnetsrv.id
    private_ip_address_allocation = "Static"
    private_ip_address            = count.index == 0 ? "192.168.30.10" : "192.168.30.20"
    public_ip_address_id          = azurerm_public_ip.pub-nginx-ip[count.index].id
  }
}


####### describe serveurs NIC apache ##########


resource "azurerm_public_ip" "pub-apache-ip" {
  count               = 2
  name                = "publicip-apache-srv-${count.index + 1}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nics-apache-srv" {
  count               = 2
  name                = "nics-apache-srv-${count.index + 1}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnetsrv.id
    private_ip_address_allocation = "Static"
    private_ip_address            = count.index == 0 ? "192.168.30.30" : "192.168.30.40"
    public_ip_address_id          = azurerm_public_ip.pub-apache-ip[count.index].id
  }
}


######## NSG #################

resource "azurerm_network_security_group" "nginx_nsg" {
  name                = "NSG-Nginx"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name


  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }


  security_rule {
    name                       = "HTTP"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "apache_nsg" {
  name                = "NSG-Apache"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name


  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}



######### create Vms nginx #################

resource "azurerm_linux_virtual_machine" "nginx" {
  count                           = 2
  name                            = "nginx-vm-${count.index}"
  location                        = var.location
  resource_group_name             = data.azurerm_resource_group.rg.name
  size                            = "Standard_DS2_v2"
  admin_username                  = "adminuser"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.nics-nginx-srv[count.index].id]


  admin_ssh_key {
    username   = "adminuser"
    public_key = file("C:/Users/Sylvain/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }


  source_image_id = "/subscriptions/ec907711-acd7-4191-9983-9577afbe3ce1/resourceGroups/Ansible-grp-Syl/providers/Microsoft.Compute/images/nginx-srv"

}

######## create Vms Apache #################

resource "azurerm_linux_virtual_machine" "apache" {
  count                           = 2
  name                            = "apache-vm-${count.index}"
  location                        = var.location
  resource_group_name             = data.azurerm_resource_group.rg.name
  size                            = "Standard_DS2_v2"
  admin_username                  = "adminuser"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.nics-apache-srv[count.index].id]


  admin_ssh_key {
    username   = "adminuser"
    public_key = file("C:/Users/Sylvain/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_id = "/subscriptions/ec907711-acd7-4191-9983-9577afbe3ce1/resourceGroups/Ansible-grp-Syl/providers/Microsoft.Compute/images/apache2-srv"


}

