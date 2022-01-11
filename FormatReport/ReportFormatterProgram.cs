using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Security.Cryptography.X509Certificates;
using OfficeOpenXml;
using OfficeOpenXml.Style;
using OfficeOpenXml.Table;

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
            var rawReport = rdr.ReadRaw("TLS-Reports");
            foreach (var reportPoint in rawReport)
            {
                var osAndVersion = FormatOsName(reportPoint.OsAndVersion);
                /*
                if (!string.IsNullOrEmpty(reportPoint.SystemOpenSslVersion))
                    osAndVersion += $", {reportPoint.SystemOpenSslVersion}";
                    */

                reportPoint.OsAndVersion = osAndVersion;
            }

            var osList = rawReport.Select(x => x.OsAndVersion).Distinct().OrderBy(x => x).ToList();
            osList = OsSorting.Sort(osList);
            Console.WriteLine($"OS: {string.Join(",",osList)}");

            var netList = rawReport.Select(x => x.GetNet()).Distinct().OrderBy(x => x).ToList();
            Console.WriteLine($".NET: {string.Join(",", netList)}");

            var siteList = rawReport.Select(x => x.Site).Distinct().OrderBy(x => x).ToList();
            Console.WriteLine($"Site: {string.Join(",", siteList)}");

            var tlsList = rawReport.Where(x => x.GetTls() != null).Select(x => x.GetTls()).Distinct().OrderBy(x => x).ToList();
            Console.WriteLine($"TLS: {string.Join(",", tlsList)}");


            var excelFile = @$"TLS-Report-{DateTime.Now:yyyy-MM-dd-HH-mm-ss}.xlsx";
            var file = new FileInfo(excelFile);
            Console.WriteLine(file.FullName);
            using (var package = new ExcelPackage(file))
            {
                ExcelWorksheet sheet = package.Workbook.Worksheets.GetOrAddByName(SheetName);

                int iTls = 0;
                foreach (var tls in tlsList)
                {
                    var cellTlsHeader = sheet.Cells[1, 3 + iTls * netList.Count, 1, (iTls + 1) * netList.Count + 2];
                    cellTlsHeader.Value = $"TLS {tls}";
                    cellTlsHeader.Merge = true;
                    cellTlsHeader.Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;

                    int iNet = 0;
                    foreach (var net in netList)
                    {
                        var cellNetHeader = sheet.Cells[2, 3 + iTls * netList.Count + iNet];
                        var ignoreErrors = sheet.IgnoredErrors.Add(cellNetHeader);
                        ignoreErrors.NumberStoredAsText = true;
                        cellNetHeader.Value = $"v{net}";
                        cellNetHeader.Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;

                        int iOs = 0;
                        foreach (var os in osList)
                        {
                            int x = iTls * netList.Count + iNet;
                            int y = iOs;
                            if (x == 0)
                            {
                                var systemOpenSslVersion = rawReport
                                    .FirstOrDefault(x => x.OsAndVersion == os && !string.IsNullOrEmpty(x.SystemOpenSslVersion))
                                    ?.SystemOpenSslVersion;

                                // OpenSSL Version
                                var cellOpenSslVer = sheet.Cells[y + 3, 2];
                                cellOpenSslVer.Value = systemOpenSslVersion;
                                cellOpenSslVer.Style.Border.Right.SetStyleAndColor(ExcelBorderStyle.Thin, DataColor);

                                // OS
                                var cellOs = sheet.Cells[y + 3, 1];
                                cellOs.Value = os;
                                cellOs.Style.Border.Right.SetStyleAndColor(ExcelBorderStyle.Thin, DataColor);
                                cellOs.Style.Border.Left.SetStyleAndColor(ExcelBorderStyle.Thin, DataColor);
                                cellOs.Style.Indent = 1;

                                // Entire row
                                var row = sheet.Rows[y + 3];
                                row.Height = 24;
                                row.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
                                row.Style.Border.Bottom.SetStyleAndColor(ExcelBorderStyle.Thin, DataColor);
                            }

                            var point = rawReport.FirstOrDefault(
                                x => x.GetTls() == tls && x.GetNet() == net && x.OsAndVersion == os
                            );

                            var cellPoint = sheet.Cells[y + 3, x + 3];
                            cellPoint.Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;
                            if (iNet + 1 == netList.Count)
                                cellPoint.Style.Border.Right.SetStyleAndColor(ExcelBorderStyle.Thin, DataColor);

                            bool isException = point?.Exception?.Length > 0;
                            bool isOk = point?.HttpStatus?.Length > 0;
                            if (isOk)
                            {
                                cellPoint.Value = " ✔️"; // ☑ ✅
                                bool isValidated = point?.SslError == "None";
                                cellPoint.Style.Font.Color.SetColor(isValidated ? Color.DarkGreen : Color.OrangeRed);
                            }
                            else if (isException)
                            {
                                cellPoint.Value = "❎"; // ⚠ ❗ 🤕 no way 💩 🤬😡🥵🤕👺👹💔❗
                                cellPoint.Style.Font.Color.SetColor(Color.DarkRed);
                                cellPoint.Style.Font.Bold = true;
                            }

                            iOs++;
                        }

                        iNet++;
                    }

                    iTls++;
                }

                sheet.Columns[1].AutoFit(25);
                sheet.Columns[2].AutoFit(5);

                ExcelRange tableHeader = sheet.Cells[1, 1, 2, 2 + netList.Count * tlsList.Count];
                tableHeader.SetAllBorders(ExcelBorderStyle.Thin, HeaderColor);
                tableHeader.Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;
                // tableHeader.Style.Font.Size = 12;
                tableHeader.Style.Font.Bold = true;


                var rowsHeader = sheet.Rows[1, 2];
                rowsHeader.Height = 26;
                rowsHeader.Style.VerticalAlignment = ExcelVerticalAlignment.Center;

                ExcelRange topLeftCell = sheet.Cells[1, 1, 2, 1];
                topLeftCell.Value = ".NET Core on Linux";
                topLeftCell.Merge = true;
                topLeftCell.Style.VerticalAlignment = ExcelVerticalAlignment.Center;

                ExcelRange sslVerCell = sheet.Cells[1, 2, 2, 2];
                sslVerCell.Value = $"System{Environment.NewLine}OpenSSL";
                sslVerCell.Merge = true;
                sslVerCell.Style.WrapText = true;
                sslVerCell.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
                sslVerCell.Style.WrapText = true;

                sheet.PrinterSettings.Orientation = eOrientation.Portrait;
                sheet.PrinterSettings.PaperSize = ePaperSize.A3;
                sheet.PrinterSettings.LeftMargin = sheet.PrinterSettings.RightMargin = 0.2m;

                var dataColumns = sheet.Columns[3, 2 + netList.Count * tlsList.Count];
                dataColumns.Width = 5.9;

                sheet.View.FreezePanes(3, 2);

                package.Save();
            }

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
