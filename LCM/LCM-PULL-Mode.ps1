#v4 PullMode LCM Configuration 
# 2016


Configuration SetPullMode
{
    param(
        [Parameter(HelpMessage='Host or FQDN of the system')]
        [ValidateNotNullOrEmpty()] 
        [string]$ComputerName = 'localhost',

        [Parameter(HelpMessage='Host or FQDN of the Pull Serversystem')]
        [ValidateNotNullOrEmpty()] 
        [string]$PullServer,

        [Parameter(HelpMessage='Host or FQDN of the Pull Serversystem')]
        [ValidateNotNullOrEmpty()] 
        [string]$ConfigurationID = [GUID]::NewGuid().Guid
        
    )
    Node $ComputerName
    {
        LocalConfigurationManager
        {
            # Module can be download from the pullserver
            AllowModuleOverwrite           = $true                     
            # Guid of a certificate to protect the configuration this cert must also be availabale in the filesystem 
            # on the authering system 
            #CertificateID                  =
            # ConfigurationMode possible values are ApplyOnly, ApplyAndMonitor or ApplyAndAutoCorrect
            ConfigurationMode              = 'ApplyAndAutoCorrect'
            ConfigurationID                = $ConfigurationID
            ConfigurationModeFrequencyMins = 15
            # RefreshFrequencyMins should be set to an integer multiple of ConfigurationModeFrequencyMins 
            RefreshFrequencyMins           = 30
            # RefreshMode possible values are pull or push 
            RefreshMode                    = 'PULL'
            RebootNodeIfNeeded             = $False
            # DownloadManagerName - two names available WebDownloadManager for Web, DSCFileDownloadManger for SMB Shares
            DownloadManagerName            = 'WebDownloadManager'
            DownloadManagerCustomData      = @{
                ServerURL                 = "https://$PullServer:8080/PSDSCPullServer.svr"
                AllowUnsecureConnection   = $False
            }
        }
    }
}

SetPullMode -Computername server.contoso.com -ConfiuratonID 992aafbd-28e2-49fe-bb4e-c1404e5891f8 -PullServer PullServer.contoso.com
# Psedit .\SetPullMode\server.contoso.com.meta.mof

Set-DscLocalConfigurationManager -Server server.contoso.com -Path .\SetPullMode -Verbose