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
                var osAndVersion = Read1File(Path.Combine(dirLaunch.FullName, "os")).Trim('\r', '\n');
                var netVersion = Read1File(Path.Combine(dirLaunch.FullName, "net")).Trim('\r', '\n');
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