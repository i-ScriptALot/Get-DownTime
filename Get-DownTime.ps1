function Get-DownTime {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)]
        [string[]]
        $ComputerName,
        [Int]$MaxEvents = 10
    )
    
    begin {        
    }
    
    process {
        Foreach ($Device in $ComputerName) {

            try {
                $null = Test-Connection -ComputerName $Device -Count 1 -ErrorAction Stop
                $ButtonDates = Get-WinEvent -MaxEvents $MaxEvents -ComputerName $Device `
                    -FilterHashtable @{LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; ID = 41 } |
                    ForEach-Object {
                        if ( ($_.ToXml() | Select-Xml -XPath "//*[@Name][7]").ToString() -eq 0) {
                            get-date $_.TimeCreated
                        } 
                    }

                $Events = Get-WinEvent -ComputerName $Device -FilterHashtable `
                @{ID = '6008', '41'; LogName = 'System' } -MaxEvents $MaxEvents -ErrorAction stop 
                $Events | Where-Object -FilterScript { $_.ProviderName -match 'event' } |
                    ForEach-Object {
                        $B = $_.message -replace '.*?(\d.*\s[A,P]M)\son\s.([\d,\/].+\d).+', '$2' -replace '\/', '-'
                        $C = $_.message -replace '.*?(\d.*\s[A,P]M)\son\s.([\d,\/].+\d).+', '$1' 
                        $D = ($B -replace '[^\d,-]', '')
                        $TImeStampDown = Get-date "$D $C"
                        $CreateTime = $_.timecreated
                        if ($ButtonDates) {
                            $ButtonDates | ForEach-Object {
                                $PressDate = $_
                                If ( ($PressDate -lt $CreateTime) -and ($PressDate -gt $TImeStampDown)) {
                                    $ButtonPress = 'Unexpected'
                                }
                                else {
                                    $ButtonPress = 'Pressed Power Button'
                                }               
                            }
                        }
                        else {
                            $ButtonPress = 'Pressed Power Button'
                        }

                        $ObjProp = [ordered]@{
                            ComputerName   = $Device
                            Down_TimeStamp = $TImeStampDown -f 'mm/dd/yyy HH:MM:ss'
                            Up_TimeStamp   = $CreateTime -f 'mm/dd/yyy HH:MM:ss'
                            MinutesDown    = (New-TimeSpan -Start $TImeStampDown -End $CreateTime).TotalMinutes
                            RebootInfo     = $ButtonPress
                        }
                        If ($ObjProp.MinutesDown -gt 0) {
                            New-Object PSObject -Property $ObjProp
                        }
                    }    
        }
        Catch {
            $ObjProp = [ordered]@{
                ComputerName   = $Device
                Down_TimeStamp = 'NA'
                Up_TimeStamp   = 'NA'
                MinutesDown    = 'na'
                RebootInfo     = 'No Reboots or No Connection'
            }
            New-Object PSObject -Property $ObjProp                   
        } # end Try Catch

    } # end Foreach

} # End Process
    
end {      
}
}
