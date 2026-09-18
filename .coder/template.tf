terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "coder" {}

provider "docker" {}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

variable "docker_image" {
  description = "Container image used for the Coder workspace."
  type        = string
  default     = "codercom/enterprise-base:ubuntu"
}

resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"
  dir  = "/home/coder/kostabber.koplugin"

  startup_script = <<-EOT
    set -eu
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
      git \
      lua5.1 \
      lua5.1-dev \
      make \
      zip
    if ! command -v lua >/dev/null 2>&1; then
      sudo ln -s /usr/bin/lua5.1 /usr/local/bin/lua
    fi
    if ! command -v luac >/dev/null 2>&1; then
      sudo ln -s /usr/bin/luac5.1 /usr/local/bin/luac
    fi
    if [ ! -d /home/coder/kostabber.koplugin/.git ]; then
      git clone https://github.com/bomdia/kostabber.koplugin.git \
        /home/coder/kostabber.koplugin
    fi
  EOT
}

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
}

resource "docker_container" "workspace" {
  name     = "coder-${data.coder_workspace.me.id}"
  hostname = data.coder_workspace.me.name
  image    = docker_image.workspace.image_id

  command = ["sh", "-c", "trap 'exit 0' TERM; while true; do sleep 1; done"]

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
  }

  restart = "unless-stopped"
}

resource "docker_image" "workspace" {
  name         = var.docker_image
  keep_locally = true
}

resource "coder_metadata" "workspace" {
  count       = data.coder_workspace.me.start_count
  resource_id = docker_container.workspace.id

  item {
    key   = "image"
    value = var.docker_image
  }

  item {
    key   = "repository"
    value = "kostabber.koplugin"
  }
}
