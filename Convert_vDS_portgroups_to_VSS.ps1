# ===============================================================================================
# 
# COMMENT: This script gets all the vDS port groups for a given distributed switch and creates a 
# VSS equivalent port group on each host in a given cluster.
#
# Changes:
#    Version 1.0 - Original - Theo Crithary
#
# ===============================================================================================

# Squelching CN Warnings when making initial connection to VCs
# First, capture existing preference
$wpref = $WarningPreference
# Then, set to 'SilentlyContinue'
$WarningPreference="SilentlyContinue"

"Welcome, this script will prompt you to enter a source vDS switch and destination cluster."
"Then, a VSS equivalent port group will be created for each of the port groups found on the source vDS"

########################################################
#### Get user input details
do {
	$vc = read-host -prompt "Enter VC to connect to"
} while ($vc -eq "")
do {
	$vDS = read-host -prompt "Enter the name of the source vDS"
} while ($vDS -eq "")
do {
	$pg_sub = read-host -prompt "How many characters should be removed from the first part of the name?"
} while ($pg_sub -eq "")
do {
	$Cluster = read-host -prompt "Enter destination cluster name (as shown in VIC)"
} while ($Cluster -eq "")

# Get user login details if ran from a non-hosted server, comment this section out if running from a hosted server
do {
	$cred = Get-Credential
} while ($cred -eq "")


########################################################
#### Running Script

# Connect to vCenter server (edit this connection if running from a hosted server)
Connect-VIServer -server $vc -Credential $cred

# Get the vDS switch and confirm it exists
$gvDS = Get-VirtualSwitch | where {$_.Name -like $vDS}

# Get the vDS portgroups
$gvDS | Get-VirtualPortGroup | where {$_.Name -notlike "dvSwitch_X3850X5_NIC_100s"} | Get-View | % {
	$pg_name = $_.Name
	[int]$vlan_id = $_.Config.DefaultPortConfig.Vlan.VlanId
	$pg_subname = $pg_name.Substring($pg_sub)
	
	"Portgroup: " + $pg_name
	# Get the ESX hosts for the given cluster
	Get-Cluster -Name $Cluster | Get-VMHost | % {
		if ($_ | Get-VirtualPortGroup | where {$_.ExtensionData -like "VMware.Vim.HostPortGroup" -and $_.Name -like $pg_subname -and $_.VlanId -like $vlan_id}) {	# Get the VSS portgroups for each host and check for vDS VLAN
			"VLAN already exists on host: " + $_.Name
		} else {
			"VLAN does not exist on host: " + $_.Name + ", adding it now...."
			$vswitch = Get-VMHost $_.Name | Get-VirtualSwitch | where {$_.ExtensionData -like "VMware.Vim.HostVirtualSwitch"} 
			"vSwitch: " + $vswitch.Name + ", Portgroup name: " + $pg_subname + ", VLAN: " + $vlan_id
			New-VirtualPortGroup -VirtualSwitch $vswitch -VLanId $vlan_id -Name $pg_subname
			
		}
	}
}

########################################################
#### End of script, resetting environment

Disconnect-VIServer $vc -Confirm:$false

# Now resetting warning preference to original setting
$WarningPreference = $wpref


