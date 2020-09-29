terraform {
  required_providers {
    vsphere = {
      source = "hashicorp/vsphere"
      version = "1.22.0"
    }
  }
}
  
    provider "vsphere" {
        user = "${var.username}"
        password = "${var.password}"
        vsphere_server = "${var.vmmanage}"
        allow_unverified_ssl = true
    }

    data "vsphere_datacenter" "dc" {
        name ="Home"
    }

    data "vsphere_datastore" "datastore" {
        name = "nfs_ds"
        datacenter_id = data.vsphere_datacenter.dc.id
    }

    data "vsphere_network" "network" {
        name = "VLAN_LAB_PG"
        datacenter_id = data.vsphere_datacenter.dc.id
    }

    data "vsphere_resource_pool" "pool" {
        name          = "Main/Resources"
        datacenter_id = data.vsphere_datacenter.dc.id
    }

    data "vsphere_virtual_machine" "template" {
        name          = "centos_7_templ"
        datacenter_id = data.vsphere_datacenter.dc.id
    }

    resource "vsphere_virtual_machine" "linux" {
        count            = var.instances
        name             = "${var.name}${count.index}"
        resource_pool_id = data.vsphere_resource_pool.pool.id
        datastore_id     = data.vsphere_datastore.datastore.id

        num_cpus = 2
        memory   = 2048
        guest_id = "centos64Guest"

        scsi_type = "lsilogic"

        network_interface {
            network_id = data.vsphere_network.network.id
        }

        disk {
            label = "disk0"
            size = 50

        }

        clone {
            
            template_uuid = data.vsphere_virtual_machine.template.id

            customize {
                
                network_interface {}

                linux_options {
                    host_name = "${var.name}${count.index}"
                    domain    = "puppet.demo"
                }
            }
        }
    }

    resource "vsphere_virtual_machine" "nginx" {
        name = "nginxranch"
        resource_pool_id = data.vsphere_resource_pool.pool.id
        datastore_id     = data.vsphere_datastore.datastore.id
        
        num_cpus = 2
        memory   = 2048
        guest_id = "centos64Guest"

        scsi_type = "lsilogic"

        network_interface {
            network_id = data.vsphere_network.network.id
        }

        disk {
            label = "disk0"
            size = 50
        }

        clone {
            
            template_uuid = data.vsphere_virtual_machine.template.id

            customize {
                
                network_interface {}

                linux_options {
                    host_name = "nginxranch"
                    domain    = "puppet.demo"
                }
            }
        }
    }

    output "names" {
        value = "${
            formatlist(
                "%s", vsphere_virtual_machine.linux[*].name
            )
        }"
    }

    output "ipaddress" {
        value = "${
            formatlist(
                "%s.%s:%s", vsphere_virtual_machine.linux[*].name,
                vsphere_virtual_machine.linux[*].clone.0.customize.0.linux_options.0.domain,
                vsphere_virtual_machine.linux[*].default_ip_address
            )
        }"
    }