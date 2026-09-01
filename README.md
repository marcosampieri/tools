# tools

A small collection of PowerShell scripts I've written to automate recurring IT infrastructure and endpoint-lifecycle tasks — inspired by 25+ years of hands-on systems administration (Active Directory, Windows Server, Microsoft 365/Azure, endpoint security).

These are generic, sanitized examples written for demonstration purposes. No production data, credentials, hostnames, or employer-specific information are included — replace the placeholder variables (marked `<...>`) with your own environment's values before use.

## Scripts

### `Invoke-SecureDeviceDecommission.ps1`
Automates a secure device decommissioning workflow: verifies BitLocker/encryption status, exports an asset inventory record, disables and moves the corresponding Active Directory object to a "Disabled Computers" OU, and logs the action (technician, timestamp, asset tag) to a CSV audit trail. Designed around the kind of certified end-of-life data destruction process I defined and ran in a previous role.

## About

Marco Sampieri — Senior ICT Infrastructure & Systems Administrator, Switzerland.
[linkedin.com/in/marcosampieri](https://linkedin.com/in/marcosampieri)
