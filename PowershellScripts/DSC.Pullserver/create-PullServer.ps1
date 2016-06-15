# DSC configuration for Pull Server
# Prerequisite: Certificate "CN=PSDSCPullServerCert" in "CERT:\LocalMachine\MY\" store for SSL
# Prerequisite: $RegistrationKey value generated using ([guid]::NewGuid()).Guid
# Note: A Certificate may be generated using MakeCert.exe: http://msdn.microsoft.com/en-us/library/windows/desktop/aa386968%28v=vs.85%29.aspx

configuration CreatePullServer {
    param (
        [Parameter(HelpMessage='Host or FQDN of the system')]
        [ValidateNotNullOrEmpty()] 
        [string]$ComputerName = "localhost",

        [Parameter(HelpMessage='Use AllowUnencryptedTraffic for setting up a non SSL based endpoint (Recommended only for test purpose)')]
        [ValidateNotNullOrEmpty()] 
        [string] $certificateThumbPrint,

        [Parameter(HelpMessage='This should be a string with enough entropy (randomness) to protect the registration of clients to the pull server.  We will use new GUID by default.')]
        [ValidateNotNullOrEmpty()]
        [string] $RegistrationKey = ([guid]::NewGuid()).Guid,

        [Parameter(HelpMessage='This should be the drive letter there the DSC Configurations will be stored during editing.')]
        [ValidateNotNullOrEmpty()]
        [string] $DriveLetter = 'E'

    )

    Import-DSCResource -ModuleName xPSDesiredStateConfiguration, xWebAdministration
    Import-DSCResource -ModuleName PSDesiredStateConfiguration
    

    Node $ComputerName {

        #Configure the server to automatically correct the configuration drift.
        LocalConfigurationManager{
            ConfigurationMode = 'ApplyAndAutoCorrect'
            RebootNodeIfNeeded = $false 
        }

        # The next series of settings disable SSL and enable TLS, for environments where that is required by policy.
        Registry TLS1_2ServerEnabled
        {
            Ensure = 'Present'
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
            ValueName = 'Enabled'
            ValueData = 1
            ValueType = 'Dword'
        } 
        Registry TLS1_2ServerDisabledByDefault
        {
            Ensure = 'Present'
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
            ValueName = 'DisabledByDefault'
            ValueData = 0
            ValueType = 'Dword'
        }
        Registry TLS1_2ClientEnabled
        {
            Ensure = 'Present'
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'
            ValueName = 'Enabled'
            ValueData = 1
            ValueType = 'Dword'
        }
        Registry TLS1_2ClientDisabledByDefault
        {
            Ensure = 'Present'
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'
            ValueName = 'DisabledByDefault'
            ValueData = 0
            ValueType = 'Dword'
        }
        Registry SSL2ServerDisabled
        {
            Ensure = 'Present'
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server'
            ValueName = 'Enabled'
            ValueData = 0
            ValueType = 'Dword'
        } 


        WindowsFeature DSCServiceFeature {
            Ensure = “Present”
            Name   = “DSC-Service”
        }

        xDscWebService PSDSCPullServer {
            Ensure                  = “Present”
            EndpointName            = “PSDSCPullServer”
            Port                    = 8080
            PhysicalPath            = “$env:SystemDrive\inetpub\wwwroot\PSDSCPullServer”
            CertificateThumbPrint   = $certificateThumbPrint
            ModulePath              = “$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules”
            ConfigurationPath       = “$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration”
            State                   = “Started”
            DependsOn               = “[WindowsFeature]DSCServiceFeature”
        }
         
        # Validate web config file contains current DB settings
        xWebConfigKeyValue CorrectDBProvider
        { 
            ConfigSection = 'AppSettings'
            Key = 'dbprovider'
            # Old PS4 Value = 'System.Data.OleDb'
            Value = 'ESENT'
            WebsitePath = 'IIS:\sites\PSDSCPullServer'
            DependsOn = '[xDSCWebService]PSDSCPullServer'
        }
        xWebConfigKeyValue CorrectDBConnectionStr
        { 
            ConfigSection = 'AppSettings'
            Key = 'dbconnectionstr'
            # Old Value = 'Provider=Microsoft.Jet.OLEDB.4.0;Data Source=C:\Program Files\WindowsPowerShell\DscService\Devices.mdb;'
            Value = 'C:\Program Files\WindowsPowerShell\DscService\Devices.edb'
            WebsitePath = 'IIS:\sites\PSDSCPullServer'
            DependsOn = '[xDSCWebService]PSDSCPullServer'
        }

        # Stop the default website
        xWebsite StopDefaultSite  
        { 
            Ensure = 'Present'
            Name = 'Default Web Site'
            State = 'Stopped'
            PhysicalPath = 'C:\inetpub\wwwroot'
            DependsOn = '[WindowsFeature]DSCServiceFeature'
        } 


        File RegistrationKeyFile
        {
            Ensure                  ='Present'
            Type                    = 'File'
            DestinationPath         = "$env:ProgramFiles\WindowsPowerShell\DscService\RegistrationKeys.txt"
            Contents                = $RegistrationKey
        }

        # Create Directory Structur
        File ConfigurationDir {
            Ensure                  ='Present'
            Type                    = 'Directory'
            Recurse                 = $true
            DestinationPath         = "$DriveLetter`:\DSCRepo\Configurations"
            
        }

        File ConfigDataDir {
            Ensure                  ='Present'
            Type                    = 'Directory'
            Recurse                 = $true
            DestinationPath         = "$Driveletter`:\DSCRepo\ConfigData"
            
        }
    }
 }

#This line actually calls the function above to create the MOF file.

CreatePullServer –ComputerName pullserver.contoso.com -certificateThumbPrint ‎04ccf13c0ea9bb4f090e9edcc1168d5283b4b283
Start-DscConfiguration .\CreatePullserver -ComputerName pullserver.contoso.com  -Wait -Verbose -Force
