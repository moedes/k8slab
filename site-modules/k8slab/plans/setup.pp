plan k8slab::setup (
    TargetSpec $targets,
    Optional[String] $action = 'apply',
    Optional[String] $hostname,
    Optional[String] $instances = undef,
) {

  if ($action == 'apply') {
    run_task('terraform::initialize', $targets, 'dir' => '/Users/jerrymozes/code/homelab_iac/Boltdir')
    run_plan('terraform::apply', 'dir' => '~/code/homelab_iac/Boltdir', 'var' => {name => "${hostname}", instances => "${instances}"})
    $dnsserver = get_target('dnsserver')
    $puppetserver = get_target('puppetserver')
    $references = {
        '_plugin'        => 'terraform',
        'dir'            => '~/code/homelab_iac/Boltdir',
        'resource_type'  => 'vsphere_virtual_machine.linux',
        'target_mapping' => {
            'uri' => 'default_ip_address',
            'name' => 'name',
            'config' => {
              'ssh'  => {
                'host' => 'default_ip_address',
              }
            }
        }
    }
    $nginxref = {
        '_plugin'        => 'terraform',
        'dir'            => '~/code/homelab_iac/Boltdir',
        'resource_type'  => 'vsphere_virtual_machine.nginx',
        'target_mapping' => {
            'uri' => 'default_ip_address',
            'name' => 'name',
            'config' => {
              'ssh'  => {
                'host' => 'default_ip_address',
              }
            }
        }
    }

    $linuxsvrs = resolve_references($references)
    $nginx = resolve_references($nginxref)

    $lin_targets = $linuxsvrs.map |$target| {
        Target.new($target)
    }

    $nginx_targets = $nginx.map |$target| {
        Target.new($target)
    }

    $alltargs = get_targets([$nginx_targets, $lin_targets])

    wait_until_available($alltargs, 'wait_time' => 300, '_catch_errors' => true)

    $install_uri = 'https://pmaster01.homelab.local:8140/packages/current/install.bash'
    $install_cmd = 'curl --insecure "https://pmaster01.homelab.local:8140/packages/current/install.bash" | sudo bash -s extension_requests:pp_role=rke'

    run_command($install_cmd, $alltargs)
    # ctrl::sleep(180)
    # apply_prep($alltargs)
    #run_task('puppet_agent::install', $lin_targets)

    wait_until_available($alltargs, 'wait_time' => 300)

    run_command("/opt/puppetlabs/bin/puppet config set server ${puppetserver.uri} --section main", $alltargs)
    run_command('/opt/puppetlabs/bin/puppet resource service puppet ensure=running enable=true', $alltargs)
    run_plan('reboot', $alltargs)

    get_targets($alltargs).each | $target | {
      run_task('k8slab::dnsadd', $dnsserver, target => $target.name, ip => $target.uri)
    }
  }

  if ($action == 'destroy'){
    $dnsserver = get_target('dnsserver')
    $puppetserver = get_target('puppetserver')
    get_targets('linux').each | $target | {
      $purge = "puppet node purge ${target.name}.puppet.demo"
      out::message($purge)
      run_command($purge, $puppetserver)
      run_command("Remove-DNSServerResourceRecord -Zonename puppet.demo -Name ${target.name} -RRType A -RecordData ${target.uri} -Force", $dnsserver)
    }
    run_plan('terraform::destroy', 'var' => {name => "${hostname}"})
  }
}
