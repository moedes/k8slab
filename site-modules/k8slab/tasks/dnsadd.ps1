param ($target,$ip)

$record = Get-DNSServerResourceRecord -Zonename puppet.demo -Name $target

if (!$record){
    Add-DNSServerResourceRecordA -Zonename puppet.demo -Name $target -IPv4Address $ip
}
else {
    Remove-DNSServerResourceRecord -Zonename puppet.demo -Name $target -RRType A -RecordData $ip -Force
    Add-DNSServerResourceRecordA -Zonename puppet.demo -Name $target -IPv4Address $ip
}