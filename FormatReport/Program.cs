using System;

namespace FormatReport
{
    class Program
    {
        static void Main(string[] args)
        {
            TlsReportReader rdr = new TlsReportReader();
            var rawReport = rdr.ReadRaw("TLS-Reports");

            foreach (var reportPoint in rawReport)
            {
                Console.WriteLine(reportPoint);
            }

        }
    }
}
