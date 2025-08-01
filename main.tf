terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    null = {
      source = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "local" {}
provider "null" {}

# Make sure the PS1 script exists
resource "local_file" "apply_gpo" {
  filename = "${path.module}/apply_gpo.ps1"
  content  = file("${path.module}/apply_gpo.ps1")
}

# Execute the script after it's created
resource "null_resource" "run_gpo_script" {
  depends_on = [local_file.apply_gpo]

  provisioner "local-exec" {
    command = "powershell -ExecutionPolicy Bypass -File ${path.module}/apply_gpo.ps1"
  }
}
