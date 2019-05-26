using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net;
using System.Net.Http;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
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
            // ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;

            var sites = new[]
            {
                "google.com", "youtube.com", "facebook.com", "wikipedia.org", "wikipedia.com", "mozilla.com", "usa.gov", "tls-v1-2.badssl.com:1012",
                "tls-v1-1.badssl.com:1011", "tls-v1-0.badssl.com:1010"
            };
            ThreadPool.SetMinThreads(sites.Length + 4, 1000);
            PreJit();

            ParallelOptions op = new ParallelOptions() {MaxDegreeOfParallelism = sites.Length};
            StringBuilder report = new StringBuilder();
            Parallel.ForEach(sites, op, site =>
            {
                SslPolicyErrors sslError = SslPolicyErrors.None;

                    HttpWebRequest req1 = (HttpWebRequest) WebRequest.Create($"https://{site}");
                    req1.ServerCertificateValidationCallback +=
                        // ServicePointManager.ServerCertificateValidationCallback +=
                        delegate(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors errors)
                        {
                            if (errors != SslPolicyErrors.None)
                                sslError = errors;

                            HttpWebRequest webReq = sender as HttpWebRequest;
                            var uri = webReq.RequestUri;
                            // Console.WriteLine("SENDER: " + sender);
                            bool isOk = errors == SslPolicyErrors.None;
                            Log($"SSL {(isOk ? "Status" : "Error ")} for {site} ({uri}): {errors}",
                                isOk ? ConsoleColor.DarkGreen : ConsoleColor.DarkRed);

                            return true;
                        };



                    Log($"Starting {site} ...", ConsoleColor.DarkGray);
                    try
                    {
                        HttpWebResponse response = (HttpWebResponse) req1.GetResponse();
                        // if (site == "wikipedia.com") Debugger.Break();
                        string status = sslError == SslPolicyErrors.None ? "" : $", {sslError}";
                        var reportLine = $"HTTP Status for {site}: {(int) response.StatusCode} ({response.StatusCode}){status}";
                        Log(reportLine, ConsoleColor.White);
                        report.AppendLine(reportLine);
                    }
                    catch (Exception ex)
                    {
                        var reportLine = $"Error for {site}: {ex.GetExceptionDigest()}";
                        Log(reportLine, ConsoleColor.DarkRed);
                        report.AppendLine(reportLine);
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

    public static class ExceptionExtensions
    {
        public static string GetExceptionDigest(this Exception ex)
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
