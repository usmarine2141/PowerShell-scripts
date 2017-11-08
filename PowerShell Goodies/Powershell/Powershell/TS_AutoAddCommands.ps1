	# Detects and alerts evaluation media [AutoAdded]
	Run-DiagExpression .\TS_EvalMediaDetection.ps1

	# Debug/GFlags check [AutoAdded]
	Run-DiagExpression .\TS_DebugFlagsCheck.ps1

	# Check for ephemeral port usage [AutoAdded]
	Run-DiagExpression .\TS_PortUsage.ps1

	# SMB2ClientDriverStateCheck [AutoAdded]
	Run-DiagExpression .\TS_SMB2ClientDriverStateCheck.ps1

	# SMB2ServerDriverStateCheck [AutoAdded]
	Run-DiagExpression .\TS_SMB2ServerDriverStateCheck.ps1

	# Opportunistic Locking has been disabled and may impact performance. [AutoAdded]
	Run-DiagExpression .\TS_LockingKB296264Check.ps1

	# Evaluates whether InfocacheLevel should be increased to 0x10 hex. To resolve slow logon, slow boot issues. [AutoAdded]
	Run-DiagExpression .\TS_InfoCacheLevelCheck.ps1

	# RC_HTTPRedirectionTSGateway [AutoAdded]
	Run-DiagExpression .\RC_HTTPRedirectionTSGateway.ps1

	# RSASHA512 Certificate TLS 1.2 Compat Check [AutoAdded]
	Run-DiagExpression .\TS_DetectSHA512-TLS.ps1

	# RC_KB2647170_CnameCheck [AutoAdded]
	Run-DiagExpression .\RC_KB2647170_CnameCheck.ps1

	# IPv6Check [AutoAdded]
	Run-DiagExpression .\TS_IPv6Check.ps1

	# IPv66To4Check [AutoAdded]
	Run-DiagExpression .\RC_IPv66To4Check.ps1

	# RC_32GBMemoryKB2634907 [AutoAdded]
	Run-DiagExpression .\RC_32GBMemoryKB2634907.ps1

	# PMTU Check [AutoAdded]
	Run-DiagExpression .\TS_PMTUCheck.ps1

	# Checks for modified TcpIP Reg Parameters and recommend KB [AutoAdded]
	Run-DiagExpression .\TS_TCPIPSettingsCheck.ps1

	# 'Checks if the number of 6to4 adapters is larger than the number of physical adapters [AutoAdded]
	Run-DiagExpression .\TS_AdapterKB980486Check.ps1

	# Checks if Windows Server 2008 R2 SP1, Hyper-V, and Tunnel.sys driver are installed if they are generate alert [AutoAdded]
	Run-DiagExpression .\TS_ServerCoreKB978309Check.ps1

	# [Idea ID 2749] [Windows] SBSL Windows firewall delays acquisition of DHCP address from DHCP relay on domain-joined W7 client [AutoAdded]
	Run-DiagExpression .\TS_SBSL_DHCPRelayKB2459530.ps1

	# Missing Enterprise Hotfix Rollup for Windows7/Windows2008R2 (KB2775511) [AutoAdded]
	Run-DiagExpression .\TS_HyperVEvent106Check.ps1

	# Missing Enterprise Hotfix Rollup for Windows7/Windows2008R2 (KB2775511) [AutoAdded]
	Run-DiagExpression .\TS_KB2775511Check.ps1

	# [Idea ID 7521] [Windows] McAfee HIPS 7.0 adds numerous extraneous network adapter interfaces to registry [AutoAdded]
	Run-DiagExpression .\TS_McAfeeHIPS70Check.ps1

	# Symantec Intrusion Prevenstion System Check [AutoAdded]
	Run-DiagExpression .\TS_SymantecIPSCheck.ps1

	# [Idea ID 7345] [Windows] Perfmon - Split IO Counter [AutoAdded]
	Run-DiagExpression .\TS_DetectSplitIO.ps1

	# [Idea ID 7065] [Windows] Alert users about Windows XP EOS [AutoAdded]
	Run-DiagExpression .\TS_WindowsXPEOSCheck.ps1

	# SurfacePro3DetectWifiDriverVersion [AutoAdded]
	Run-DiagExpression .\TS_SurfacePro3DetectWifiDriverVersion.ps1

	# SurfacePro3DetectFirmwareVersions [AutoAdded]
	Run-DiagExpression .\TS_SurfacePro3DetectFirmwareVersions.ps1

	# SurfacePro3DetectConnectedStandbyStatus [AutoAdded]
	Run-DiagExpression .\TS_SurfacePro3DetectConnectedStandbyStatus.ps1

	# SurfacePro3DetectConnectedStandbyHibernationConfig [AutoAdded]
	Run-DiagExpression .\TS_SurfacePro3DetectConnectedStandbyHibernationConfig.ps1

	# AutoRuns Information [AutoAdded]
	Run-DiagExpression .\DC_Autoruns.ps1

	# Basic System Information [AutoAdded]
	Run-DiagExpression .\DC_BasicSystemInformation.ps1

	# Basic System Information TXT output [AutoAdded]
	Run-DiagExpression .\DC_BasicSystemInformationTXT.ps1

	# CheckSym [AutoAdded]
	Run-DiagExpression .\DC_ChkSym.ps1

	# MSInfo [AutoAdded]
	Run-DiagExpression .\DC_MSInfo.ps1

	# Information about Processes resource usage and top Kernel memory tags [AutoAdded]
	Run-DiagExpression .\TS_ProcessInfo.ps1

	# GPResults.exe Output [AutoAdded]
	Run-DiagExpression .\DC_RSoP.ps1

	# Collects Windows Server 2008/R2 Server Manager Information [AutoAdded]
	Run-DiagExpression .\DC_ServerManagerInfo.ps1

	# Services [AutoAdded]
	Run-DiagExpression .\DC_Services.ps1

	# TaskListSvc [AutoAdded]
	Run-DiagExpression .\DC_TaskListSvc.ps1

	# Update History [AutoAdded]
	Run-DiagExpression .\DC_UpdateHistory.ps1

	# Hotfix Rollups [AutoAdded]
	Run-DiagExpression .\DC_HotfixRollups.ps1

	# WhoAmI [AutoAdded]
	Run-DiagExpression .\DC_Whoami.ps1

	# 802.1x Client Component [AutoAdded]
	Run-DiagExpression .\DC_8021xClient-Component.ps1

	# BITS Client Component [AutoAdded]
	Run-DiagExpression .\DC_BitsClient-Component.ps1

	# BITS Server Component [AutoAdded]
	Run-DiagExpression .\DC_BitsServer-Component.ps1

	# BranchCache [AutoAdded]
	Run-DiagExpression .\DC_BranchCache-Component.ps1

	# Bridge [AutoAdded]
	Run-DiagExpression .\DC_Bridge-Component.ps1

	# Certificates Component [AutoAdded]
	Run-DiagExpression .\DC_Certificates-Component.ps1

	# CscClient [AutoAdded]
	Run-DiagExpression .\DC_CscClient-Component.ps1

	# DFS Client Component [AutoAdded]
	Run-DiagExpression .\DC_DFSClient-Component.ps1

	# DHCP Client Component [AutoAdded]
	Run-DiagExpression .\DC_DhcpClient-Component.ps1

	# DHCP Server Component [AutoAdded]
	Run-DiagExpression .\DC_DhcpServer-Component.ps1

	# DirectAccess Client Component [AutoAdded]
	Run-DiagExpression .\DC_DirectAccessClient-Component.ps1

	# DirectAccess Server Component [AutoAdded]
	Run-DiagExpression .\DC_DirectAccessServer-Component.ps1

	# DNS Client Component [AutoAdded]
	Run-DiagExpression .\DC_DNSClient-Component.ps1

	# DNS Server Component [AutoAdded]
	Run-DiagExpression .\DC_DNSServer-Component.ps1

	# DNS DHCP Dynamic Updates [AutoAdded]
	Run-DiagExpression .\DC_DnsDhcpDynamicUpdates.ps1

	# Fltmc [AutoAdded]
	Run-DiagExpression .\DC_Fltmc.ps1

	# Firewall [AutoAdded]
	Run-DiagExpression .\DC_Firewall-Component.ps1

	# Capture pfirewall.log  [AutoAdded]
	Run-DiagExpression .\DC_PFirewall.ps1

	# FolderRedirection [AutoAdded]
	Run-DiagExpression .\DC_FolderRedirection-Component.ps1

	# GroupPolicyClient [AutoAdded]
	Run-DiagExpression .\DC_GroupPolicyClient-Component.ps1

	# HTTP [AutoAdded]
	Run-DiagExpression .\DC_HTTP-Component.ps1

	# Hyper-V Networking Settings [AutoAdded]
	Run-DiagExpression .\DC_HyperVNetworking.ps1

	# Hyper-V Network Virtualization [AutoAdded]
	Run-DiagExpression .\DC_HyperVNetworkVirtualization.ps1

	# InternetExplorer [AutoAdded]
	Run-DiagExpression .\DC_InternetExplorer-Component.ps1

	# IPAM Component [AutoAdded]
	Run-DiagExpression .\DC_IPAM-Component.ps1

	# IPsec [AutoAdded]
	Run-DiagExpression .\DC_IPsec-Component.ps1

	# Kerberos Component [AutoAdded]
	Run-DiagExpression .\DC_Kerberos-Component.ps1

	# MUP Component [AutoAdded]
	Run-DiagExpression .\DC_MUP-Component.ps1

	# NAP Client Component [AutoAdded]
	Run-DiagExpression .\DC_NAPClient-Component.ps1

	# NAP Server Component [AutoAdded]
	Run-DiagExpression .\DC_NAPServer-Component.ps1

	# NetworkAdapters [AutoAdded]
	Run-DiagExpression .\DC_NetworkAdapters-Component.ps1

	# NetLBFO [AutoAdded]
	Run-DiagExpression .\DC_NetLBFO-Component.ps1

	# NetworkConnections [AutoAdded]
	Run-DiagExpression .\DC_NetworkConnections-Component.ps1

	# NetworkList [AutoAdded]
	Run-DiagExpression .\DC_NetworkList-Component.ps1

	# NetworkLocationAwareness [AutoAdded]
	Run-DiagExpression .\DC_NetworkLocationAwareness-Component.ps1

	# Network Shortcuts (Network Locations) [AutoAdded]
	Run-DiagExpression .\DC_NetworkShortcuts.ps1

	# NetworkStoreInterface [AutoAdded]
	Run-DiagExpression .\DC_NetworkStoreInterface-Component.ps1

	# NFS Client Component [AutoAdded]
	Run-DiagExpression .\DC_NfsClient-Component.ps1

	# NFS Server Component [AutoAdded]
	Run-DiagExpression .\DC_NfsServer-Component.ps1

	# NLB Component [AutoAdded]
	Run-DiagExpression .\DC_NLB-Component.ps1

	# NPS [AutoAdded]
	Run-DiagExpression .\DC_NPS-Component.ps1

	# P2P [AutoAdded]
	Run-DiagExpression .\DC_P2P-Component.ps1

	# Proxy Configuration [AutoAdded]
	Run-DiagExpression .\DC_ProxyConfiguration.ps1

	# RAS [AutoAdded]
	Run-DiagExpression .\DC_RAS-Component.ps1

	# RDG Component [AutoAdded]
	Run-DiagExpression .\DC_RDG-Component.ps1

	# Remote File Systems Client Component [AutoAdded]
	Run-DiagExpression .\DC_RemoteFileSystemsClient-Component.ps1

	# Remote File Systems Server Component [AutoAdded]
	Run-DiagExpression .\DC_RemoteFileSystemsServer-Component.ps1

	# RPC [AutoAdded]
	Run-DiagExpression .\DC_RPC-Component.ps1

	# SChannel [AutoAdded]
	Run-DiagExpression .\DC_SChannel-Component.ps1

	# SMB Client Component [AutoAdded]
	Run-DiagExpression .\DC_SMBClient-Component.ps1

	# SMB Server Component [AutoAdded]
	Run-DiagExpression .\DC_SMBServer-Component.ps1

	# SNMP [AutoAdded]
	Run-DiagExpression .\DC_SNMP-Component.ps1

	# TCPIP Component [AutoAdded]
	Run-DiagExpression .\DC_TCPIP-Component.ps1

	# WebClient [AutoAdded]
	Run-DiagExpression .\DC_WebClient-Component.ps1

	# WinHTTP [AutoAdded]
	Run-DiagExpression .\DC_WinHTTP-Component.ps1

	# WINSClient [AutoAdded]
	Run-DiagExpression .\DC_WINSClient-Component.ps1

	# WinSock [AutoAdded]
	Run-DiagExpression .\DC_WinSock-Component.ps1

	# WINSServer [AutoAdded]
	Run-DiagExpression .\DC_WINSServer-Component.ps1

	# CscClient [AutoAdded]
	Run-DiagExpression .\DC_NetworkingDiagnostic.ps1

	# Surface Pro 3 [AutoAdded]
	Run-DiagExpression .\DC_SurfacePro3.ps1

	# Running powercfg.exe to obtain power settings information [AutoAdded]
	Run-DiagExpression .\TS_PowerCFG.ps1

	# List Schedule Tasks using schtasks.exe utility [AutoAdded]
	Run-DiagExpression .\DC_ScheduleTasks.ps1

	# Obtain pstat output [AutoAdded]
	Run-DiagExpression .\DC_PStat.ps1

	# Performance Monitor - System Performance Data Collector [AutoAdded]
	Run-DiagExpression .\TS_PerfmonSystemPerf.ps1 -NumberOfSeconds 60 -DataCollectorSetXMLName "SystemPerformance.xml"

	# Hyper-V Info [AutoAdded]
	Run-DiagExpression .\TS_HyperVInfo.ps1

	# Hyper-V Networking Info [AutoAdded]
	Run-DiagExpression .\DC_HyperVNetInfo.ps1


# SIG # Begin signature block
# MIIa7wYJKoZIhvcNAQcCoIIa4DCCGtwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUVPE4r9/durHT9s63LRp0aQeK
# pnagghWCMIIEwzCCA6ugAwIBAgITMwAAAEyh6E3MtHR7OwAAAAAATDANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTMxMTExMjIxMTMx
# WhcNMTUwMjExMjIxMTMxWjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjENMAsGA1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0UgRVNO
# OkMwRjQtMzA4Ni1ERUY4MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsdj6GwYrd6jk
# lF18D+Z6ppLuilQdpPmEdYWXzMtcltDXdS3ZCPtb0u4tJcY3PvWrfhpT5Ve+a+i/
# ypYK3EbxWh4+AtKy4CaOAGR7vjyT+FgyeYfSGl0jvJxRxA8Q+gRYtRZ2buy8xuW+
# /K2swUHbqs559RyymUGneiUr/6t4DVg6sV5Q3mRM4MoVKt+m6f6kZi9bEAkJJiHU
# Pw0vbdL4d5ADbN4UEqWM5zYf9IelsEEXb+NNdGbC/aJxRjVRzGsXUWP6FZSSml9L
# KLrmFkVJ6Sy1/ouHr/ylbUPcpjD6KSjvmw0sXIPeEo1qtNtx71wUWiojKP+BcFfx
# jAeaE9gqUwIDAQABo4IBCTCCAQUwHQYDVR0OBBYEFLkNrbNN9NqfGrInJlUNIETY
# mOL0MB8GA1UdIwQYMBaAFCM0+NlSRnAK7UD7dvuzK7DDNbMPMFQGA1UdHwRNMEsw
# SaBHoEWGQ2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
# L01pY3Jvc29mdFRpbWVTdGFtcFBDQS5jcmwwWAYIKwYBBQUHAQEETDBKMEgGCCsG
# AQUFBzAChjxodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFRpbWVTdGFtcFBDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQEFBQADggEBAAmKTgav6O2Czx0HftcqpyQLLa+aWyR/lHEMVYgkGlIVY+KQ
# TQVKmEqc++GnbWhVgrkp6mmpstXjDNrR1nolN3hnHAz72ylaGpc4KjlWRvs1gbnk
# PUZajuT8dTdYWUmLTts8FZ1zUkvreww6wi3Bs5tSLeA1xbnBV7PoPaE8RPIjFh4K
# qlk3J9CVUl6ofz9U8IHh3Jq9ZdV49vdMObvd4NY3DpGah4xz53FkUvc+A9jGzXK4
# NDSYW4zT9Qim63jGUaANDm/0azxAGmAWLKkGUp0cE5DObwIe6nucs/b4l2DyZdHR
# H4c6wXXwQo167Yxysnv7LIq0kUdU4i5pzBZUGlkwggTsMIID1KADAgECAhMzAAAA
# ymzVMhI1xOFVAAEAAADKMA0GCSqGSIb3DQEBBQUAMHkxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xIzAhBgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBMB4XDTE0MDQyMjE3MzkwMFoXDTE1MDcyMjE3MzkwMFowgYMxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xDTALBgNVBAsTBE1PUFIx
# HjAcBgNVBAMTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAJZxXe0GRvqEy51bt0bHsOG0ETkDrbEVc2Cc66e2bho8
# P/9l4zTxpqUhXlaZbFjkkqEKXMLT3FIvDGWaIGFAUzGcbI8hfbr5/hNQUmCVOlu5
# WKV0YUGplOCtJk5MoZdwSSdefGfKTx5xhEa8HUu24g/FxifJB+Z6CqUXABlMcEU4
# LYG0UKrFZ9H6ebzFzKFym/QlNJj4VN8SOTgSL6RrpZp+x2LR3M/tPTT4ud81MLrs
# eTKp4amsVU1Mf0xWwxMLdvEH+cxHrPuI1VKlHij6PS3Pz4SYhnFlEc+FyQlEhuFv
# 57H8rEBEpamLIz+CSZ3VlllQE1kYc/9DDK0r1H8wQGcCAwEAAaOCAWAwggFcMBMG
# A1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBQfXuJdUI1Whr5KPM8E6KeHtcu/
# gzBRBgNVHREESjBIpEYwRDENMAsGA1UECxMETU9QUjEzMDEGA1UEBRMqMzE1OTUr
# YjQyMThmMTMtNmZjYS00OTBmLTljNDctM2ZjNTU3ZGZjNDQwMB8GA1UdIwQYMBaA
# FMsR6MrStBZYAck3LjMWFrlMmgofMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9j
# cmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY0NvZFNpZ1BDQV8w
# OC0zMS0yMDEwLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljQ29kU2lnUENBXzA4LTMx
# LTIwMTAuY3J0MA0GCSqGSIb3DQEBBQUAA4IBAQB3XOvXkT3NvXuD2YWpsEOdc3wX
# yQ/tNtvHtSwbXvtUBTqDcUCBCaK3cSZe1n22bDvJql9dAxgqHSd+B+nFZR+1zw23
# VMcoOFqI53vBGbZWMrrizMuT269uD11E9dSw7xvVTsGvDu8gm/Lh/idd6MX/YfYZ
# 0igKIp3fzXCCnhhy2CPMeixD7v/qwODmHaqelzMAUm8HuNOIbN6kBjWnwlOGZRF3
# CY81WbnYhqgA/vgxfSz0jAWdwMHVd3Js6U1ZJoPxwrKIV5M1AHxQK7xZ/P4cKTiC
# 095Sl0UpGE6WW526Xxuj8SdQ6geV6G00DThX3DcoNZU6OJzU7WqFXQ4iEV57MIIF
# vDCCA6SgAwIBAgIKYTMmGgAAAAAAMTANBgkqhkiG9w0BAQUFADBfMRMwEQYKCZIm
# iZPyLGQBGRYDY29tMRkwFwYKCZImiZPyLGQBGRYJbWljcm9zb2Z0MS0wKwYDVQQD
# EyRNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkwHhcNMTAwODMx
# MjIxOTMyWhcNMjAwODMxMjIyOTMyWjB5MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSMwIQYDVQQDExpNaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBD
# QTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALJyWVwZMGS/HZpgICBC
# mXZTbD4b1m/My/Hqa/6XFhDg3zp0gxq3L6Ay7P/ewkJOI9VyANs1VwqJyq4gSfTw
# aKxNS42lvXlLcZtHB9r9Jd+ddYjPqnNEf9eB2/O98jakyVxF3K+tPeAoaJcap6Vy
# c1bxF5Tk/TWUcqDWdl8ed0WDhTgW0HNbBbpnUo2lsmkv2hkL/pJ0KeJ2L1TdFDBZ
# +NKNYv3LyV9GMVC5JxPkQDDPcikQKCLHN049oDI9kM2hOAaFXE5WgigqBTK3S9dP
# Y+fSLWLxRT3nrAgA9kahntFbjCZT6HqqSvJGzzc8OJ60d1ylF56NyxGPVjzBrAlf
# A9MCAwEAAaOCAV4wggFaMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFMsR6MrS
# tBZYAck3LjMWFrlMmgofMAsGA1UdDwQEAwIBhjASBgkrBgEEAYI3FQEEBQIDAQAB
# MCMGCSsGAQQBgjcVAgQWBBT90TFO0yaKleGYYDuoMW+mPLzYLTAZBgkrBgEEAYI3
# FAIEDB4KAFMAdQBiAEMAQTAfBgNVHSMEGDAWgBQOrIJgQFYnl+UlE/wq4QpTlVnk
# pDBQBgNVHR8ESTBHMEWgQ6BBhj9odHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtp
# L2NybC9wcm9kdWN0cy9taWNyb3NvZnRyb290Y2VydC5jcmwwVAYIKwYBBQUHAQEE
# SDBGMEQGCCsGAQUFBzAChjhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2Nl
# cnRzL01pY3Jvc29mdFJvb3RDZXJ0LmNydDANBgkqhkiG9w0BAQUFAAOCAgEAWTk+
# fyZGr+tvQLEytWrrDi9uqEn361917Uw7LddDrQv+y+ktMaMjzHxQmIAhXaw9L0y6
# oqhWnONwu7i0+Hm1SXL3PupBf8rhDBdpy6WcIC36C1DEVs0t40rSvHDnqA2iA6VW
# 4LiKS1fylUKc8fPv7uOGHzQ8uFaa8FMjhSqkghyT4pQHHfLiTviMocroE6WRTsgb
# 0o9ylSpxbZsa+BzwU9ZnzCL/XB3Nooy9J7J5Y1ZEolHN+emjWFbdmwJFRC9f9Nqu
# 1IIybvyklRPk62nnqaIsvsgrEA5ljpnb9aL6EiYJZTiU8XofSrvR4Vbo0HiWGFzJ
# NRZf3ZMdSY4tvq00RBzuEBUaAF3dNVshzpjHCe6FDoxPbQ4TTj18KUicctHzbMrB
# 7HCjV5JXfZSNoBtIA1r3z6NnCnSlNu0tLxfI5nI3EvRvsTxngvlSso0zFmUeDord
# EN5k9G/ORtTTF+l5xAS00/ss3x+KnqwK+xMnQK3k+eGpf0a7B2BHZWBATrBC7E7t
# s3Z52Ao0CW0cgDEf4g5U3eWh++VHEK1kmP9QFi58vwUheuKVQSdpw5OPlcmN2Jsh
# rg1cnPCiroZogwxqLbt2awAdlq3yFnv2FoMkuYjPaqhHMS+a3ONxPdcAfmJH0c6I
# ybgY+g5yjcGjPa8CQGr/aZuW4hCoELQ3UAjWwz0wggYHMIID76ADAgECAgphFmg0
# AAAAAAAcMA0GCSqGSIb3DQEBBQUAMF8xEzARBgoJkiaJk/IsZAEZFgNjb20xGTAX
# BgoJkiaJk/IsZAEZFgltaWNyb3NvZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0wNzA0MDMxMjUzMDlaFw0yMTA0MDMx
# MzAzMDlaMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAf
# BgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQTCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAJ+hbLHf20iSKnxrLhnhveLjxZlRI1Ctzt0YTiQP7tGn
# 0UytdDAgEesH1VSVFUmUG0KSrphcMCbaAGvoe73siQcP9w4EmPCJzB/LMySHnfL0
# Zxws/HvniB3q506jocEjU8qN+kXPCdBer9CwQgSi+aZsk2fXKNxGU7CG0OUoRi4n
# rIZPVVIM5AMs+2qQkDBuh/NZMJ36ftaXs+ghl3740hPzCLdTbVK0RZCfSABKR2YR
# JylmqJfk0waBSqL5hKcRRxQJgp+E7VV4/gGaHVAIhQAQMEbtt94jRrvELVSfrx54
# QTF3zJvfO4OToWECtR0Nsfz3m7IBziJLVP/5BcPCIAsCAwEAAaOCAaswggGnMA8G
# A1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFCM0+NlSRnAK7UD7dvuzK7DDNbMPMAsG
# A1UdDwQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADCBmAYDVR0jBIGQMIGNgBQOrIJg
# QFYnl+UlE/wq4QpTlVnkpKFjpGEwXzETMBEGCgmSJomT8ixkARkWA2NvbTEZMBcG
# CgmSJomT8ixkARkWCW1pY3Jvc29mdDEtMCsGA1UEAxMkTWljcm9zb2Z0IFJvb3Qg
# Q2VydGlmaWNhdGUgQXV0aG9yaXR5ghB5rRahSqClrUxzWPQHEy5lMFAGA1UdHwRJ
# MEcwRaBDoEGGP2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL21pY3Jvc29mdHJvb3RjZXJ0LmNybDBUBggrBgEFBQcBAQRIMEYwRAYIKwYB
# BQUHMAKGOGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljcm9z
# b2Z0Um9vdENlcnQuY3J0MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEB
# BQUAA4ICAQAQl4rDXANENt3ptK132855UU0BsS50cVttDBOrzr57j7gu1BKijG1i
# uFcCy04gE1CZ3XpA4le7r1iaHOEdAYasu3jyi9DsOwHu4r6PCgXIjUji8FMV3U+r
# kuTnjWrVgMHmlPIGL4UD6ZEqJCJw+/b85HiZLg33B+JwvBhOnY5rCnKVuKE5nGct
# xVEO6mJcPxaYiyA/4gcaMvnMMUp2MT0rcgvI6nA9/4UKE9/CCmGO8Ne4F+tOi3/F
# NSteo7/rvH0LQnvUU3Ih7jDKu3hlXFsBFwoUDtLaFJj1PLlmWLMtL+f5hYbMUVbo
# nXCUbKw5TNT2eb+qGHpiKe+imyk0BncaYsk9Hm0fgvALxyy7z0Oz5fnsfbXjpKh0
# NbhOxXEjEiZ2CzxSjHFaRkMUvLOzsE1nyJ9C/4B5IYCeFTBm6EISXhrIniIh0EPp
# K+m79EjMLNTYMoBMJipIJF9a6lbvpt6Znco6b72BJ3QGEe52Ib+bgsEnVLaxaj2J
# oXZhtG6hE6a/qkfwEm/9ijJssv7fUciMI8lmvZ0dhxJkAj0tr1mPuOQh5bWwymO0
# eFQF1EEuUKyUsKV4q7OglnUa2ZKHE3UiLzKoCG6gW4wlv6DvhMoh1useT8ma7kng
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TGCBNcwggTT
# AgEBMIGQMHkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAh
# BgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBAhMzAAAAymzVMhI1xOFV
# AAEAAADKMAkGBSsOAwIaBQCggfAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFBsU
# OG08rGjbARow1OWIx2U/i7mqMIGPBgorBgEEAYI3AgEMMYGAMH6gZIBiAEMAVABT
# AF8ATgBlAHQAdwBvAHIAawBpAG4AZwBfAE0AYQBpAG4AXwBnAGwAbwBiAGEAbABf
# AFQAUwBfAEEAdQB0AG8AQQBkAGQAQwBvAG0AbQBhAG4AZABzAC4AcABzADGhFoAU
# aHR0cDovL21pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAR86Pb2zN9U6X
# /IaIDArwwxIoyvsuenlPpN/RfQZoOqtEndQ+Q6T93SfMmpMraOckpSh43CGBO7nZ
# oL4/YMV1xPd0BhLr7+ODvHqo3GamUW19TEnbgUXBzqVHBvtvpydMZ2fza7jD1tTb
# BjBUBA/OYhe8pqVgToTytEgOniOZ4AZp01tkbWLvQpedgw/bRjqUskSWnsxiaaI5
# H/qBUs9FYMTD9BoOGO5YgMqCWd3+SkaQHUSQJIIfUVHZexhCB2UXZaoTNPARhVrG
# bT8h/QiKq8Fe+9sBZcF99HeacXOx3JdN3fxjLxRcFy89cRNK6qNicModhIa+fN/8
# 2x6RrbOCFaGCAigwggIkBgkqhkiG9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3Nv
# ZnQgVGltZS1TdGFtcCBQQ0ECEzMAAABMoehNzLR0ezsAAAAAAEwwCQYFKw4DAhoF
# AKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE0
# MTAyMDE4MDgzOVowIwYJKoZIhvcNAQkEMRYEFH1dcIaDgGaBNYkklQCO9p7xhqsC
# MA0GCSqGSIb3DQEBBQUABIIBACDun70E5bpoBOzpG6rTbXe1azSk1ZIF/TOKFxxI
# K9Eruw3FW4Smdm6yDP6Zp7A2uPxq77NPdEMYoXPAJUTtNmFBC/8SFi3jvbVP8kB4
# MP0dpH0LOEIL0uq7zqg5FIa8KaqnRBbLgFs4ePeHk/0ex65IjyhIQYz87C00GQhJ
# ihDS6lF1HOwY1gdNct6Rqd8ntVbjoxZ02o+NV0fazLw8SnhzFBCpExBQcod0McCQ
# nlBj7WQ/qO3F2xAzt1nsQOPuH0m5MvcD5yx1O5jFgGzTheYZSYcyM2A836DinyN7
# 94K0r42KlLJhWySV2AwATH3c6jk+uGz6SjPUSkwFcjOOELE=
# SIG # End signature block
