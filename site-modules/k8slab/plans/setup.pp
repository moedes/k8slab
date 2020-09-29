plan k8slab::setup (
    TargetSpec $targets,
    Optional[String] $action = 'apply',
    Optional[String] $hostname
) {

  if ($action == 'apply') {
    run_task('terraform::initialize', $targets, 'dir' => '/Users/jerrymozes/projects/homelab_iac/Boltdir')
    run_plan('terraform::apply', 'dir' => '~/projects/homelab_iac/Boltdir', 'var' => {name => "${hostname}"})
    $dnsserver = get_target('dns01.homelab.local')
    $references = {
        '_plugin'        => 'terraform',
        'dir'            => '~/projects/homelab_iac/Boltdir',
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
        'dir'            => '~/projects/homelab_iac/Boltdir',
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

    apply_prep($alltargs)
    #run_task('puppet_agent::install', $lin_targets)

    wait_until_available($alltargs, 'wait_time' => 300)

    run_command('/opt/puppetlabs/bin/puppet config set server pmaster01.homelab.local --section main', $alltargs)
    run_command('/opt/puppetlabs/bin/puppet resource service puppet ensure=running enable=true', $alltargs)
    run_plan('reboot', $alltargs)

    get_targets($alltargs).each | $target | {
      run_task('k8slab::dnsadd', $dnsserver, target => $target.name, ip => $target.uri)
    }
  }

  if ($action == 'destroy'){
    $dnsserver = get_target('dns01.homelab.local')
    $master = get_target('pmaster01.homelab.local')
    get_targets('linux').each | $target | {
      $purge = "puppet node purge ${target.name}.puppet.demo"
      out::message($purge)
      run_command($purge, $master)
      run_command("Remove-DNSServerResourceRecord -Zonename puppet.demo -Name ${target.name} -RRType A -RecordData ${target.uri} -Force", $dnsserver)
    }
    run_plan('terraform::destroy', 'var' => {name => "${hostname}"})
  }
}
