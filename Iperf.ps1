$protocol = 'TCP'
$port = 5201
$parallel_sessions = 1
$iteration_time = 28800
$retry_timeout = 15
$unit = "m"

$global:LogFilePath ='C:\iperf\Iperf_LogFile.log'
$limit = (Get-Date).AddDays(-7)
Get-ChildItem -Path $LogFilePath -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $limit } | Remove-Item -Force
Function Write-Log
{
    param (
        [Parameter(Mandatory)]
        [string]$Message
    )
    
    $line = [pscustomobject]@{
        'DateTime' = (Get-Date)
        'Message' = $Message
    }
    
    $line | Add-Content -Path $LogFilePath
}

Function updateBenchmarkSpeed{ param($nasidentifier,$speed)
        $url_update ="testapi.com/update"
        $params = @{$nasidentifier = $speed}
        $Message=  $params
        $iperf_server2= Invoke-WebRequest -Uri $url_update -Method POST -Body $params
        return $iperf_server2.StatusCode
        }

Function getIperfServer{ param($nasidentifier)
        $url = "testapi.com/IperfServer"
        $querystring = @{sHost=$nasidentifier}
        $headers = @{"x-psk" = "FGtbAXMT4QBBLQj97jvP"}
        $iperf_server= Invoke-WebRequest $url -Method GET -Headers $headers -Body $querystring -UseBasicParsing | ConvertFrom-Json
        if ($iperf_server -ne ""){
                if ($iperf_server.header.code = 1){
                        return $iperf_server.body.iperf
                        }

                else{
                        return False
                        }
                }
        }
Function parse_output{ param($cmd) 
        
        $result_output=$cmd[15].Split("  ")
        $postresult=$result_output[12]
        for ($i=0; $i -lt $result_output.length; $i++) {
	        if ($result_output[$i] -contains "Mbits/sec"){
                $final= $i-1
                return $result_output[$final]
            }
        }
    }

Function startTest { param($retrycount=0)
        $retrycount = $retrycount + 1
        $retrycount_message='Retry Count=' + $retrycount
        Write-Log -Message $retrycount_message
        $nasidentifier = [System.Net.Dns]::GetHostName()
        $nasidentifier_output='Hostname=' + $nasidentifier
        Write-Log -Message $nasidentifier_output
        $iperfServer = getIperfServer -nasidentifier $nasidentifier
        $iperfserver_output= 'Iperfserver=' + $iperfServer
        if ($iperfServer -ne ""){
                cd C:\iperf\iperf-3.1.3-win64
                Write-Log -Message $iperfserver_output
                $cmd = .\iperf3.exe -c $iperfServer -p $port -f $unit -P $parallel_sessions
                $result = $cmd -contains 'iperf Done.'
                $speed=parse_output -cmd $cmd
                $speed_output='Speed=' +$speed
                Write-Log -Message $speed_output
                
                if ($result -eq "true"){
                       $update_oo=updateBenchmarkSpeed -nasidentifier $nasidentifier -speed $speed
                       if ($update_oo -eq  200){
                       $update_message='Update Successful'
                       Write-Log -Message  $update_message
                       }
                        }
                
                else {
                        
                        $newtimeout = $retry_timeout+ $retrycount
                        Start-Sleep -s $newtimeout
                        startTest -retrycount $retrycount}
                        }
        else {
               Start-Sleep -s $newtimeout
               startTest -retrycount $retrycount
               }
          }
starttest
Start-Sleep -s $iteration_time