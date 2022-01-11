using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Security;
using System.Runtime.InteropServices;
using System.Security.Authentication;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace CheckHttps
{
    class Program
    {
        private static readonly Stopwatch StartAt = Stopwatch.StartNew();
        private static readonly object SyncLog = new object();

        static readonly SslProtocols? TheSslProtocols =
            SslProtocols.Tls | SslProtocols.Tls11 | SslProtocols.Tls12 | SslProtocols.Tls13;

        private static int _errorsCount;
        private static StringBuilder _report;
        private static List<string> _errors;
        private static bool _muteLog = true;
        private static readonly object SyncReport = new object();

        static string ReportDir
        {
            get
            {
                var raw = Environment.GetEnvironmentVariable("TLS_REPORT_DIR");
                return string.IsNullOrEmpty(raw) ? "." : raw;
            }
        }
        

        static int Main()
        {
            var sites = new[]
            {
                "google.com", "youtube.com", "facebook.com", "wikipedia.org", "wikipedia.com", "mozilla.com", "usa.gov",
                "tls-v1-2.badssl.com:1012", "tls-v1-1.badssl.com:1011", "tls-v1-0.badssl.com:1010",
                "tls13.1d.pw", // - does not work
                "raw.githubusercontent.com"
            };
            ThreadPool.SetMinThreads(sites.Length + 4, 1000);

            System.Net.ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12 | SecurityProtocolType.Tls11 |
                                                              SecurityProtocolType.Tls13 | SecurityProtocolType.Tls;


            // JIT
            _report = new StringBuilder();
            _errors = new List<string>();
            _errorsCount = 0;
            _muteLog = true;
            Stopwatch sw = Stopwatch.StartNew();
            TrySite("mozilla.com");
            sw.Stop();
            // Perform
            _errorsCount = 0;
            _errors.Clear();
            _report.Clear();
            StartAt.Restart();
            _muteLog = false;
            Log($"Runtime: {RuntimeInformation.FrameworkDescription}", ConsoleColor.DarkGray);
            Log($"SSL Protocols: {TheSslProtocols}", ConsoleColor.DarkGray);
            Log($"JIT for http client completed in {sw.ElapsedMilliseconds:n0} msec", ConsoleColor.DarkGray);
            ParallelOptions op = new ParallelOptions() {MaxDegreeOfParallelism = sites.Length};
            Parallel.ForEach(sites, op, TrySite);

            Log($"TOTAL SUMMARY:{Environment.NewLine}{_report}".TrimEnd('\n', '\r'), ConsoleColor.Green);
            if (_errors.Count > 0)
            {
                Log($"TOTAL {_errors.Count} errors:{Environment.NewLine}{string.Join(Environment.NewLine, _errors)}", ConsoleColor.DarkRed);

            }
            return _errorsCount;
        }

        private static void TrySite(string site)
        {
            var requestUri = $"https://{site}";
            var MaxRetryCount = 3;
            for (int indexTry = 1; indexTry <= MaxRetryCount; indexTry++)
            {
                var idSite = new Uri(requestUri).Host;
                StoreReportField(idSite, "site", site);
                SslPolicyErrors sslError = SslPolicyErrors.None;
                using (HttpClientHandler handler = new HttpClientHandler())
                using (HttpClient httpClient = new HttpClient(handler))
                {
                    string infoPrefix = indexTry == 1 ? "" : $"(try {indexTry} of {MaxRetryCount}) ";
                    if (TheSslProtocols.HasValue) handler.SslProtocols = TheSslProtocols.Value;
                    handler.AllowAutoRedirect = false;
                    // handler.SslProtocols = SslProtocols.Tls12;.
                    // handler.AllowAutoRedirect = true;
                    handler.ServerCertificateCustomValidationCallback += (message, certificate2, chain, error) =>
                    {
                        if (error != SslPolicyErrors.None)
                            sslError = error;

                        if (true || error != SslPolicyErrors.None)
                            Log($"{infoPrefix}SSL Error Status for {site} ({message.RequestUri}): {error}",
                                error == SslPolicyErrors.None ? ConsoleColor.DarkGreen : ConsoleColor.DarkRed);

                        return true;
                    };

                    Log($"{infoPrefix}Starting {site} ...", ConsoleColor.DarkGray);
                    try
                    {
                        HttpRequestMessage req = new HttpRequestMessage(HttpMethod.Get, requestUri);
                        var response = httpClient.SendAsync(req).Result;
                        if (site == "wikipedia.com" && Debugger.IsAttached) Debugger.Break();
                        string status = sslError == SslPolicyErrors.None ? "" : $", {sslError}";
                        var reportLine =
                            $"{site} OK. HTTP Status {(int)response.StatusCode} ({response.StatusCode}){status}";
                        Log($"{infoPrefix}{reportLine}", ConsoleColor.White);
                        lock (SyncReport) _report.AppendLine(reportLine);
                        StoreReportField(idSite, "http-status", ((int) response.StatusCode).ToString());
                        StoreReportField(idSite, "ssl-error", sslError.ToString());
                        return;
                    }
                    catch (Exception ex)
                    {
                        var reportLine =
                            $"{site}: {GetExceptionDigest(ex)}"; // {Environment.NewLine}{ex}
                        Log($"{infoPrefix}{reportLine}", ConsoleColor.DarkRed);
                        if (indexTry == MaxRetryCount)
                        {
                            // _report.AppendLine(reportLine);
                            lock(SyncReport) _errors.Add(reportLine);
                            Interlocked.Increment(ref _errorsCount);
                            StoreReportField(idSite, "exception", ex.ToString());
                            StoreReportField(idSite, "exception-messages", GetExceptionDigest(ex));
                            StoreReportField(idSite, "exception-inner-message", GetInnerMessage(ex));
                        }
                    }
                }
            }
        }


        static string GetStorageDir(string idSite)
        {
            return Path.Combine(ReportDir, $"TLS-Report-{idSite}");
        }

        static void StoreReportField(string idSite, string name, string value)
        {
            if (string.IsNullOrWhiteSpace(ReportDir)) return;
            var fullName = Path.Combine(GetStorageDir(idSite), $"Field-{name}.storage");
            try
            {
                Directory.CreateDirectory(new FileInfo(fullName).Directory.FullName);
            }
            catch
            {
            }

            File.WriteAllText(fullName, value ?? "");
        }

        static void Log(string message, ConsoleColor fore)
        {
            if (_muteLog) return;
            double msec = StartAt.ElapsedTicks * 1000d / Stopwatch.Frequency;
            // for colorless terminals
            Action<Action> tryAndForget = (action) =>
            {
                try
                {
                    action();
                }
                catch
                {
                }
            };

            lock (SyncLog)
            {
                ConsoleColor back = ConsoleColor.DarkGray;
                tryAndForget(() => back = Console.BackgroundColor);
                if (back == ConsoleColor.DarkGray && fore == ConsoleColor.DarkGray)
                    fore = ConsoleColor.Gray;

                ConsoleColor prev = ConsoleColor.White;
                tryAndForget(() => prev = Console.ForegroundColor);
                tryAndForget(() => Console.ForegroundColor = ConsoleColor.DarkGray);
                Console.Write($"{msec.ToString("0.000"),11}");
                tryAndForget(() => Console.ForegroundColor = fore);
                Console.WriteLine($" {message}");
                tryAndForget(() => Console.ForegroundColor = prev);
            }
        }

        public static string GetInnerMessage(Exception ex)
        {
            Exception ret = null;
            while (ex != null)
            {
                ret = ex;
                ex = ex.InnerException;
            }

            return "[" + ret.GetType().Name + "] " + ret.Message;
        }

        public static string GetExceptionDigest(Exception ex)
        {
            List<string> ret = new List<string>();
            while (ex != null)
            {
                ret.Add("[" + ex.GetType().Name + "] " + ex.Message);
                ex = ex.InnerException;
            }

            return string.Join(" --> ", ret);
        }

    }
}