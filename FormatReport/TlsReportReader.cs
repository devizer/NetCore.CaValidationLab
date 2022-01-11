using System;
using System.Collections.Generic;
using System.IO;

namespace FormatReport
{
    class ReportPoint
    {
        public string OsAndVersion { get; set; }
        public string NetVersion { get; set; }
        public string Site { get; set; }
        public string HttpStatus { get; set; }
        public string SslError { get; set; }
        public string Exception { get; set; }
        public string ExceptionMessages { get; set; }
        public string SystemOpenSslVersion { get; set; }

        public string GetNet()
        {
            return new Version(NetVersion).ToString(2);
        }

        // Site: facebook.com,google.com,mozilla.com,raw.githubusercontent.com,tls13.1d.pw,tls-v1-0.badssl.com:1010,tls-v1-1.badssl.com:1011,tls-v1-2.badssl.com:1012,usa.gov,wikipedia.com,wikipedia.org,youtube.com
        public string GetTls()
        {
            if (Site.StartsWith("tls13.1d.pw")) return "1.3";
            if (Site.StartsWith("tls-v1-2.badssl.com")) return "1.2";
            if (Site.StartsWith("tls-v1-1.badssl.com")) return "1.1";
            if (Site.StartsWith("tls-v1-0.badssl.com")) return "1.0";
            return null;
        }

        public override string ToString()
        {
            if (Exception == null)
                return $"{nameof(OsAndVersion)}: {OsAndVersion}, {nameof(NetVersion)}: {NetVersion}, {nameof(Site)}: {Site}, {nameof(HttpStatus)}: {HttpStatus}, {nameof(SslError)}: {SslError}";
            else
                return $"{nameof(OsAndVersion)}: {OsAndVersion}, {nameof(NetVersion)}: {NetVersion}, {nameof(Site)}: {Site}, {nameof(ExceptionMessages)}: '{ExceptionMessages}'";

        }
    }

    class TlsReportReader
    {
        private static readonly string[] Properties = new[]
        {
            "http-status", "ssl-error",
            "exception", "exception-messages",
            "site",
        };

        public List<ReportPoint> ReadRaw(string rootPath)
        {
            List<ReportPoint> ret = new List<ReportPoint>();
            var dirs = new DirectoryInfo(rootPath).GetDirectories();
            foreach (var dirLaunch in dirs)
            {
                var osAndVersion = Read1File(Path.Combine(dirLaunch.FullName, "os"))?.Trim('\r', '\n');
                var netVersion = Read1File(Path.Combine(dirLaunch.FullName, "net"))?.Trim('\r', '\n');
                var systemOpenSslVersion = Read1File(Path.Combine(dirLaunch.FullName, "openssl"))?.Trim('\r', '\n');
                var dirSites = dirLaunch.GetDirectories();
                foreach (var dirSite in dirSites)
                {
                    string GetField(string fieldName)
                    {
                        return Read1File(Path.Combine(dirSite.FullName, $"Field-{fieldName}.storage"));
                    }

                    var site = GetField("site");
                    var sslError = GetField("ssl-error");
                    var exception = GetField("exception");
                    var exceptionMessages = GetField("exception-messages");
                    var httpStatus = GetField("http-status");

                    var reportPoint = new ReportPoint()
                    {
                        Exception = exception,
                        ExceptionMessages = exceptionMessages,
                        HttpStatus = httpStatus,
                        NetVersion = netVersion,
                        OsAndVersion = osAndVersion,
                        Site = site,
                        SslError = sslError,
                        SystemOpenSslVersion = systemOpenSslVersion,
                    };
                    ret.Add(reportPoint);

                }


            }

            return ret;
        }

        static string Read1File(string file)
        {
            if (!File.Exists(file))
                return null;

            return File.ReadAllText(file);
        }
        



    }
}