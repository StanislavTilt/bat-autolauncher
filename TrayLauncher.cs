using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace BatLauncherTray
{
    static class Program
    {
        const string MutexName = "Local\\BatLauncherTray";

        static Mutex _singleInstanceMutex;
        static NotifyIcon _tray;
        static string _exeDir;
        static string _launcherBat;
        static string _logsDir;
        static IntPtr _job = IntPtr.Zero;

        [STAThread]
        static void Main()
        {
            Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
            Application.ThreadException += (s, e) => LogException("Thread", e.Exception);
            AppDomain.CurrentDomain.UnhandledException +=
                (s, e) => LogException("AppDomain", e.ExceptionObject as Exception);

            _exeDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
            _launcherBat = Path.Combine(_exeDir, "launcher.bat");
            _logsDir = Path.Combine(_exeDir, "logs");

            bool createdNew;
            try
            {
                _singleInstanceMutex = new Mutex(true, MutexName, out createdNew);
            }
            catch (Exception ex)
            {
                LogException("Mutex", ex);
                return;
            }
            if (!createdNew) return;

            try
            {
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);

                EnsureJob();
                Application.ApplicationExit += (s, e) => Shutdown();

                _tray = new NotifyIcon();
                _tray.Icon = LoadTrayIcon();
                _tray.Text = "BatLauncher";
                _tray.Visible = true;

                var menu = new ContextMenuStrip();
                menu.Items.Add("Открыть папку логов", null, OnOpenLogs);
                menu.Items.Add("Перезапустить ботов", null, OnRestart);
                menu.Items.Add("Остановить ботов", null, OnStop);
                menu.Items.Add(new ToolStripSeparator());
                menu.Items.Add("Выход (закрыть и убить ботов)", null, OnExit);
                _tray.ContextMenuStrip = menu;
                _tray.DoubleClick += OnOpenLogs;

                RunLauncher(silent: false);

                Application.Run();
            }
            finally
            {
                Shutdown();
            }
        }

        static Icon LoadTrayIcon()
        {
            try
            {
                Assembly asm = typeof(Program).Assembly;
                using (Stream s = asm.GetManifestResourceStream("bot.ico"))
                {
                    if (s != null) return new Icon(s);
                }
            }
            catch (Exception ex) { LogException("icon", ex); }

            try
            {
                string ico = Path.Combine(_exeDir, "bot.ico");
                if (File.Exists(ico)) return new Icon(ico);
            }
            catch (Exception ex) { LogException("icon", ex); }

            try
            {
                Icon own = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
                if (own != null) return own;
            }
            catch (Exception ex) { LogException("icon", ex); }

            return SystemIcons.Application;
        }

        static void RunLauncher(bool silent)
        {
            if (!File.Exists(_launcherBat))
            {
                MessageBox.Show("Не найден " + _launcherBat,
                    "BatLauncher", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = "cmd.exe",
                    Arguments = "/c \"\"" + _launcherBat + "\"\"",
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden,
                    WorkingDirectory = _exeDir,
                };
                using (Process p = Process.Start(psi))
                {
                    if (p != null && _job != IntPtr.Zero)
                    {
                        if (!AssignProcessToJobObject(_job, p.Handle))
                        {
                            LogException("AssignProcessToJobObject",
                                new InvalidOperationException(
                                    "Win32 error " + Marshal.GetLastWin32Error()));
                        }
                    }
                }
                if (!silent && _tray != null)
                {
                    _tray.ShowBalloonTip(2500, "BatLauncher", "Боты запущены", ToolTipIcon.Info);
                }
            }
            catch (Exception ex)
            {
                LogException("RunLauncher", ex);
                MessageBox.Show("Не удалось запустить launcher.bat:\n" + ex.Message,
                    "BatLauncher", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        static void OnOpenLogs(object sender, EventArgs e)
        {
            try
            {
                if (!Directory.Exists(_logsDir)) Directory.CreateDirectory(_logsDir);
                using (Process.Start("explorer.exe", "\"" + _logsDir + "\"")) { }
            }
            catch (Exception ex)
            {
                LogException("OnOpenLogs", ex);
            }
        }

        static void OnRestart(object sender, EventArgs e)
        {
            KillJobProcesses();
            Thread.Sleep(400);
            RunLauncher(silent: false);
        }

        static void OnStop(object sender, EventArgs e)
        {
            KillJobProcesses();
            try
            {
                if (_tray != null)
                    _tray.ShowBalloonTip(2000, "BatLauncher", "Боты остановлены", ToolTipIcon.Info);
            }
            catch { }
        }

        static void OnExit(object sender, EventArgs e)
        {
            Application.Exit();
        }

        static int _shutdownGuard;

        static void Shutdown()
        {
            if (Interlocked.Exchange(ref _shutdownGuard, 1) != 0) return;

            try { if (_tray != null) { _tray.Visible = false; _tray.Dispose(); _tray = null; } } catch { }
            CleanupJob();
            try
            {
                if (_singleInstanceMutex != null)
                {
                    try { _singleInstanceMutex.ReleaseMutex(); } catch { }
                    _singleInstanceMutex.Dispose();
                    _singleInstanceMutex = null;
                }
            }
            catch { }
        }

        static void EnsureJob()
        {
            if (_job != IntPtr.Zero) return;
            IntPtr h = CreateJobObject(IntPtr.Zero, null);
            if (h == IntPtr.Zero)
            {
                LogException("CreateJobObject",
                    new InvalidOperationException("Win32 error " + Marshal.GetLastWin32Error()));
                return;
            }

            var info = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
            info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
            int len = Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
            IntPtr ptr = Marshal.AllocHGlobal(len);
            try
            {
                Marshal.StructureToPtr(info, ptr, false);
                if (!SetInformationJobObject(h, JobObjectInfoType.ExtendedLimitInformation, ptr, (uint)len))
                {
                    LogException("SetInformationJobObject",
                        new InvalidOperationException("Win32 error " + Marshal.GetLastWin32Error()));
                }
            }
            finally
            {
                Marshal.FreeHGlobal(ptr);
            }

            _job = h;
        }

        static void KillJobProcesses()
        {
            if (_job == IntPtr.Zero) return;
            TerminateJobObject(_job, 1);
        }

        static void CleanupJob()
        {
            if (_job == IntPtr.Zero) return;
            try { TerminateJobObject(_job, 1); } catch { }
            try { CloseHandle(_job); } catch { }
            _job = IntPtr.Zero;
        }

        static readonly object _logLock = new object();

        static void LogException(string source, Exception ex)
        {
            if (ex == null) return;
            try
            {
                if (!Directory.Exists(_logsDir)) Directory.CreateDirectory(_logsDir);
                string log = Path.Combine(_logsDir, "tray.log");

                try
                {
                    var fi = new FileInfo(log);
                    if (fi.Exists && fi.Length > 1024 * 1024)
                    {
                        string old = log + ".old";
                        if (File.Exists(old)) File.Delete(old);
                        File.Move(log, old);
                    }
                }
                catch { }

                lock (_logLock)
                {
                    File.AppendAllText(log,
                        "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "] [" + source + "] "
                        + ex.GetType().Name + ": " + ex.Message + Environment.NewLine
                        + ex.StackTrace + Environment.NewLine);
                }
            }
            catch { }
        }

        enum JobObjectInfoType
        {
            ExtendedLimitInformation = 9,
        }

        const uint JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x2000;

        [StructLayout(LayoutKind.Sequential)]
        struct IO_COUNTERS
        {
            public ulong ReadOperationCount;
            public ulong WriteOperationCount;
            public ulong OtherOperationCount;
            public ulong ReadTransferCount;
            public ulong WriteTransferCount;
            public ulong OtherTransferCount;
        }

        [StructLayout(LayoutKind.Sequential)]
        struct JOBOBJECT_BASIC_LIMIT_INFORMATION
        {
            public long PerProcessUserTimeLimit;
            public long PerJobUserTimeLimit;
            public uint LimitFlags;
            public UIntPtr MinimumWorkingSetSize;
            public UIntPtr MaximumWorkingSetSize;
            public uint ActiveProcessLimit;
            public UIntPtr Affinity;
            public uint PriorityClass;
            public uint SchedulingClass;
        }

        [StructLayout(LayoutKind.Sequential)]
        struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION
        {
            public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
            public IO_COUNTERS IoInfo;
            public UIntPtr ProcessMemoryLimit;
            public UIntPtr JobMemoryLimit;
            public UIntPtr PeakProcessMemoryUsed;
            public UIntPtr PeakJobMemoryUsed;
        }

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        static extern IntPtr CreateJobObject(IntPtr lpJobAttributes, string lpName);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool SetInformationJobObject(IntPtr hJob, JobObjectInfoType infoClass, IntPtr lpJobObjectInfo, uint cbJobObjectInfoLength);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool AssignProcessToJobObject(IntPtr hJob, IntPtr hProcess);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool TerminateJobObject(IntPtr hJob, uint uExitCode);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool CloseHandle(IntPtr hObject);
    }
}
