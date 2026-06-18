variable "REGISTRY" {
  default = "psazevedo"
}

variable "TAG" {
  default = "latest"
}

group "default" {
  targets = ["bind9"]
}

target "bind9" {
  context    = "."
  dockerfile = "Dockerfile"
  tags       = ["${REGISTRY}/bind9:${TAG}", "dns-server-bind9:${TAG}"]
  platforms  = ["linux/amd64", "linux/arm64"]
}
