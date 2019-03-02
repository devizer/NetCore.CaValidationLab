using System;
using System.Diagnostics;
using System.Net.Http;
using System.Net.Security;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace CheckHttps
{
    class Program
    {
        static readonly Stopwatch StartAt = Stopwatch.StartNew();
        static readonly object SyncLog = new object();

        static void Main()
        {
            var sites = new[] { "google.com", "youtube.com", "facebook.com", "wikipedia.org", "wikipedia.com", "mozilla.com", "usa.gov" };
            ThreadPool.SetMinThreads(sites.Length + 4, 1000);
            PreJit();

            ParallelOptions op = new ParallelOptions() {MaxDegreeOfParallelism = sites.Length};
            StringBuilder report = new StringBuilder();
            Parallel.ForEach(sites, op, site =>
            {
                SslPolicyErrors sslError = SslPolicyErrors.None;
                using (HttpClientHandler handler = new HttpClientHandler())
                using (HttpClient httpClient = new HttpClient(handler))
                {
                    handler.AllowAutoRedirect = true;
                    handler.ServerCertificateCustomValidationCallback += (message, certificate2, chain, error) =>
                    {
                        if (error != SslPolicyErrors.None)
                            sslError = error;

                        Log($"SSL Error Status for {site} ({message.RequestUri}): {error}",
                            error == SslPolicyErrors.None ? ConsoleColor.DarkGreen : ConsoleColor.DarkRed);
                        return true;
                    };

                    Log($"Starting {site} ...", ConsoleColor.DarkGray);
                    try
                    {
                        HttpRequestMessage req = new HttpRequestMessage(HttpMethod.Get, $"https://{site}");
                        var response = httpClient.SendAsync(req).Result;
                        if (site == "wikipedia.com") Debugger.Break();
                        string status = sslError == SslPolicyErrors.None ? "" : $", {sslError}";
                        var reportLine = $"HTTP Status for {site}: {(int) response.StatusCode} ({response.StatusCode}){status}";
                        Log(reportLine, ConsoleColor.White);
                        report.AppendLine(reportLine);
                    }
                    catch (Exception ex)
                    {
                        var reportLine = $"Error for {site}: {ex.GetType().Name} {ex.Message}";
                        Log(reportLine, ConsoleColor.DarkRed);
                        report.AppendLine(reportLine);
                    }
                }
            });

            Log($"TOTAL SUMMARY:{Environment.NewLine}{report}", ConsoleColor.Yellow);

        }

        static void PreJit()
        {
            const string site = "mozilla.com";
            string jitResult;
            Stopwatch sw = Stopwatch.StartNew();
            using (HttpClientHandler handler = new HttpClientHandler())
            using (HttpClient httpClient = new HttpClient(handler))
            {
                handler.AllowAutoRedirect = true;
                handler.ServerCertificateCustomValidationCallback += (message, certificate2, chain, error) =>
                {
                    return true;
                };

                try
                {
                    HttpRequestMessage req = new HttpRequestMessage(HttpMethod.Get, $"https://{site}");
                    var response = httpClient.SendAsync(req).Result;
                    jitResult = $"OK in {sw.ElapsedMilliseconds:n0} milliseconds";
                }
                catch (Exception ex)
                {
                    jitResult = $"Fail in {sw.ElapsedMilliseconds:n0} milliseconds, {ex.GetType().Name} {ex.Message}";
                }

                Log($"HttpClient jit status: {jitResult}", ConsoleColor.DarkGray);
            }
        }

        static void Log(string message, ConsoleColor fore)
        {
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
                ConsoleColor prev = ConsoleColor.White;
                tryAndForget(() => prev = Console.ForegroundColor);
                tryAndForget(() => Console.ForegroundColor = ConsoleColor.DarkGray);
                Console.Write($"{msec.ToString("0.000"),11}");
                tryAndForget(() => Console.ForegroundColor = fore);
                Console.WriteLine($" {message}");
                tryAndForget(() => Console.ForegroundColor = prev);
            }
        }
    }
}
