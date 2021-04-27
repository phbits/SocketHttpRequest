
$script:here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:module = 'SocketHttpRequest'
$script:moduleFileNames = @( "$($script:module).psm1", "$($script:module).psd1" )
$script:outputRoot = Join-Path $script:here -ChildPath '..\..\output' -Resolve
$script:moduleFiles = Get-ChildItem -Path $script:outputRoot `
                                       -Force `
                                       -Recurse `
                                       -File `
                                       -Include $script:moduleFileNames `
                                       -ErrorAction Stop

Describe "$module Module Tests" -Tags 'Unit' {
  BeforeAll {
    $scriptFile = $script:moduleFiles | ?{ $_.Name -eq "$($script:module).psm1"}
    $manifestFile = $script:moduleFiles | ?{ $_.Name -eq "$($script:module).psd1"}
    $module = 'SocketHttpRequest'
  }
  Context 'Validate Module' {
    It "has the root module $module.psm1" {
      Test-Path $scriptFile.FullName | Should -BeTrue
    }
    It "has a manifest file $module.psd1" {
      Test-Path $manifestFile.FullName | Should -BeTrue
      #$manifestFile.FullName | Should -FileContentMatch "$module.psm1"
    }
    It "has a valid manifest file." {
        Test-ModuleManifest $manifestFile.FullName | Should -BeTrue
    }
  }
  Context 'Validate Module Manifest' {
    BeforeAll {
      $manifestData = Import-PowerShellDataFile $manifestFile.Fullname
    }
    It "has root module set $($script:module).psm1" {    
      $manifestData.RootModule -eq "$($script:module).psm1" | Should -BeTrue
    }
    It 'has Author.' {
      $manifestData.Author | Should -Not -BeNullOrEmpty
    }
    It 'has CompanyName.' {
      $manifestData.CompanyName | Should -Not -BeNullOrEmpty
    }
    It 'has Copyright.' {
      $manifestData.Copyright | Should -Not -BeNullOrEmpty
    }
    It 'has Description.' {
      $manifestData.Description | Should -Not -BeNullOrEmpty
    }
    It 'has FunctionsToExport.' {
      $manifestData.FunctionsToExport | Should -Not -BeNullOrEmpty
    }
    It 'has GUID.' {
      $manifestData.GUID | Should -Not -BeNullOrEmpty
    }
    It 'has ModuleVersion.' {
      $manifestData.ModuleVersion | Should -Not -BeNullOrEmpty
    }
    It 'has PowerShellVersion.' {
      $manifestData.PowerShellVersion | Should -Not -BeNullOrEmpty
    }
    It 'has LicenseUri.' {
      $manifestData.PrivateData.PSData.LicenseUri | Should -Not -BeNullOrEmpty
    }
    It 'has ProjectUri.' {
      $manifestData.PrivateData.PSData.ProjectUri | Should -Not -BeNullOrEmpty
    }
    It 'has ReleaseNotes.' {
      $manifestData.PrivateData.PSData.ReleaseNotes | Should -Not -BeNullOrEmpty
    }
    It 'has Tags.' {
      $manifestData.PrivateData.PSData.Tags | Should -Not -BeNullOrEmpty
    }
  }
  Context 'Validate Root Module' {
    It "$module.psm1 is valid PowerShell code" {
      $psFile = Get-Content -Path $scriptFile.Fullname `
                            -ErrorAction Stop
      $errors = $null
      $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
      $errors.Count | Should -Be 0
    }
  }
  Context 'Validate Additional PowerShell Files' {
    BeforeAll {
      $additionalFiles = Get-ChildItem -Path $script:here -Force -Recurse -File `
                          -Exclude ("$($script:module).psm1","$($script:module).psd1","*Tests*") `
                          -Include ("*.ps1","*.psd1","*.psm1")
    }
    It 'has no additional .ps1/.psd1/.psm1 files.' {
      $additionalFiles.Count -eq 0 | Should -BeTrue
    }
  }
}

Describe 'SocketHttpRequest\Invoke-SocketHttpRequest' -Tag 'Unit' {
  BeforeAll {
    $allParams = (Get-Command Invoke-SocketHttpRequest).parameters
  }
  Context 'Validate parameters.' {
    It 'Should have parameter count = 19' {
      $allParams.Keys.Count -eq 19 | Should -BeTrue
    }
    It "Should have parameter: -IP" {
      $allParams.ContainsKey('IP') | Should -BeTrue
    }
    It "Should have parameter: -Port" {
      $allParams.ContainsKey('Port') | Should -BeTrue
    }
    It "Should have parameter: -HttpRequest" {
      $allParams.ContainsKey('HttpRequest') | Should -BeTrue
    }
    It "Should have parameter: -UseTLS" {
      $allParams.ContainsKey('UseTLS') | Should -BeTrue
    }
    It "Should have parameter: -FullResponse" {
      $allParams.ContainsKey('FullResponse') | Should -BeTrue
    }
    It "Should have parameter: -TlsVersion" {
      $allParams.ContainsKey('TlsVersion') | Should -BeTrue
    }
    It "Should have parameter: -IncludeCertificate" {
      $allParams.ContainsKey('IncludeCertificate') | Should -BeTrue
    }
    It "Should have parameter: -Wait" {
      $allParams.ContainsKey('Wait') | Should -BeTrue
    }
  }       
}
