# Copyright 2020 The Kubernetes Authors.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This file is from packer documentation:
# https://www.packer.io/docs/provisioners/ansible.html#winrm-communicator
# https://www.packer.io/docs/builders/amazon/ebs#connecting-to-windows-instances-using-winrm

# Log execution policies at all scopes for diagnostics
Write-Output "Current execution policy settings:"
Get-ExecutionPolicy -List | Format-Table -AutoSize | Out-String | Write-Output

# Only set execution policy if the current effective policy is more restrictive
# than what we need. Policies like Bypass or Unrestricted are already sufficient.
$currentPolicy = Get-ExecutionPolicy
$sufficientPolicies = @('Bypass', 'Unrestricted')
if ($currentPolicy -notin $sufficientPolicies) {
    Write-Output "Effective execution policy '$currentPolicy' is insufficient, setting to Unrestricted"
    try {
        Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force -ErrorAction Stop
        Write-Output "Execution policy set to Unrestricted"
    } catch {
        Write-Output "Failed to set execution policy: $_"
    }
} else {
    Write-Output "Effective execution policy '$currentPolicy' is sufficient, skipping Set-ExecutionPolicy"
}

# Don't set this before Set-ExecutionPolicy as it throws an error
$ErrorActionPreference = "stop"

# NOTE: We intentionally do NOT remove/recreate the WinRM HTTPS listener here.
# Packer's azure-arm builder already establishes a WinRM SSL connection with
# winrm_insecure=true (skip cert validation). Destroying the active listener
# kills Packer's session and causes "connection reset by peer" retry loops.
# The Ansible provisioner also uses ansible_winrm_server_cert_validation=ignore,
# so the existing listener and certificate are sufficient.

# WinRM – configure settings on the existing listener.
# Do NOT use "winrm quickconfig" here: it restarts the WinRM service internally,
# which kills Packer's active WinRM session. The service is already running
# (Packer is connected via it), and the explicit "winrm set" commands below
# apply all necessary configuration without a service restart.
write-output "Setting up WinRM"
write-host "(host) setting up WinRM"

cmd.exe /c winrm set "winrm/config" '@{MaxTimeoutms="1800000"}'
cmd.exe /c winrm set "winrm/config/winrs" '@{MaxMemoryPerShellMB="1024"}'
cmd.exe /c winrm set "winrm/config/service" '@{AllowUnencrypted="true"}'
cmd.exe /c winrm set "winrm/config/client" '@{AllowUnencrypted="true"}'
cmd.exe /c winrm set "winrm/config/service/auth" '@{Basic="true"}'
cmd.exe /c winrm set "winrm/config/client/auth" '@{Basic="true"}'
cmd.exe /c winrm set "winrm/config/service/auth" '@{CredSSP="true"}'
cmd.exe /c netsh advfirewall firewall set rule group="remote administration" new enable=yes
cmd.exe /c netsh firewall add portopening TCP 5986 "Port 5986"
cmd.exe /c sc config winrm start= auto
