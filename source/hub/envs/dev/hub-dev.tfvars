location      = "westeurope"
env_name      = "dev"

virtual_network = {
  address_space_cidr = "172.16.0.0/15"

  subnet = {
    api_server_cidr       = "172.16.0.0/24"
    private_endpoint_cidr = "172.16.255.0/26"
    cluster_cidr          = "172.17.0.0/20"
  }
}
