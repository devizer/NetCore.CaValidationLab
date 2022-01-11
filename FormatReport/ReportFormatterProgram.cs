﻿using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using OfficeOpenXml;
using OfficeOpenXml.Style;

namespace FormatReport
{
    class ReportFormatterProgram
    {

        static Color HeaderColor = Color.Black;
        static Color DataColor = Color.FromArgb(255, 170, 170, 170);
        private static readonly string SheetName = "TLS Report";

        static void Main(string[] args)
        {
            TlsReportReader rdr = new TlsReportReader();
            List<ReportPoint> rawReport = rdr.ReadRaw("TLS-Reports");
            foreach (var reportPoint in rawReport)
                reportPoint.OsAndVersion = FormatOsName(reportPoint.OsAndVersion);

            var excelFile = @$"TLS-Report-{DateTime.Now:yyyy-MM-dd-HH-mm-ss}.xlsx";

            ExcelReportBuilder builder = new ExcelReportBuilder(rawReport.ToArray());
            builder.Build(excelFile);

            ProcessStartInfo si = new ProcessStartInfo(excelFile);
            si.UseShellExecute = true;
            Process.Start(si);
        }

        static string FormatOsName(string os)
        {
            return os
                .Replace("SUSE", "Open SUSE")
                .Replace("-", " ")
                .Replace("Fedora 36", "Fedora 36 (preview)")
                .Replace("Ubuntu 22.04", "Ubuntu 22.04 (preview)");
        }

    }
}
