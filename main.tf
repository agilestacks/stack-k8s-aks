terraform {
  required_version = ">= 0.12"
  backend "azurerm" {
  }
}

provider "azurerm" {
  version = "2.31.1"
  features {}
}

provider "local" {
  version = "1.4.0"
}
