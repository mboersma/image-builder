packer {
  required_plugins {
    azure = {
      version = ">= 2.0.5"
      source  = "github.com/hashicorp/azure"
    }
  }
}
