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
        static Color DataColor = Color.FromArgb(255, 200, 200, 200);

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
                var sheet = package.Workbook.Worksheets.FirstOrDefault(x => x.Name == "TLS Report");
                if (sheet == null)
                    sheet = package.Workbook.Worksheets.Add("TLS Report");

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
                        cellNetHeader.Value = $"{net}";
                        cellNetHeader.Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;

                        int iOs = 0;
                        foreach (var os in osList)
                        {
                            int x = iTls * netList.Count + iNet;
                            int y = iOs;
                            if (x == 0)
                            {
                                var systemOpenSslVersion = rawReport.FirstOrDefault(x =>
                                        x.OsAndVersion == os && !string.IsNullOrEmpty(x.SystemOpenSslVersion))
                                    ?.SystemOpenSslVersion;

                                sheet.Cells[y + 3, 2].Value = systemOpenSslVersion;
                                sheet.Cells[y + 3, 2].Style.Border.Right.Style = ExcelBorderStyle.Thin;
                                sheet.Cells[y + 3, 2].Style.Border.Right.Color.SetColor(DataColor); 
                                sheet.Cells[y + 3, 1].Value = os;
                                sheet.Cells[y + 3, 1].Style.Border.Right.Style = ExcelBorderStyle.Thin;
                                sheet.Cells[y + 3, 1].Style.Border.Left.Style = ExcelBorderStyle.Thin;
                                sheet.Cells[y + 3, 1].Style.Border.Right.Color.SetColor(DataColor);
                                sheet.Cells[y + 3, 1].Style.Border.Left.Color.SetColor(DataColor);
                                sheet.Cells[y + 3, 1].Style.Indent = 1;
                                var row = sheet.Rows[y + 3];
                                row.Height = 24;
                                row.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
                                row.Style.Border.Bottom.Style = ExcelBorderStyle.Thin;
                                row.Style.Border.Bottom.Color.SetColor(DataColor);
                            }

                            var point = rawReport.FirstOrDefault(
                                x => x.GetTls() == tls && x.GetNet() == net && x.OsAndVersion == os
                            );

                            var cellPoint = sheet.Cells[y + 3, x + 3];
                            cellPoint.Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;
                            if (iNet + 1 == netList.Count)
                            {
                                cellPoint.Style.Border.Right.Style = ExcelBorderStyle.Thin;
                                cellPoint.Style.Border.Right.Color.SetColor(DataColor);
                            }

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
                sheet.Columns[2].AutoFit(8);

                //create a range for the table
                ExcelRange tableHeader = sheet.Cells[1, 1, 2, 2 + netList.Count * tlsList.Count];
                // tableHeader.Style.Border.(ExcelBorderStyle.Thin);
                var border1 = tableHeader.Style.Border.Top.Style =
                    tableHeader.Style.Border.Left.Style =
                        tableHeader.Style.Border.Right.Style =
                            tableHeader.Style.Border.Bottom.Style =
                                ExcelBorderStyle.Thin;

                tableHeader.Style.Border.Right.Color.SetColor(HeaderColor);
                tableHeader.Style.Border.Left.Color.SetColor(HeaderColor);
                tableHeader.Style.Border.Top.Color.SetColor(HeaderColor);
                tableHeader.Style.Border.Bottom.Color.SetColor(HeaderColor);

                tableHeader.Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;

                var rowsHeader = sheet.Rows[1, 2];
                rowsHeader.Height = 26;
                rowsHeader.Style.VerticalAlignment = ExcelVerticalAlignment.Center;

                {
                    ExcelRange topLeftCell = sheet.Cells[1, 1, 2, 1];
                    topLeftCell.Merge = true;
                    topLeftCell.Value = ".NET Core on Linux";
                    topLeftCell.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
                }
                {
                    ExcelRange sslVerCell = sheet.Cells[1, 2, 2, 2];
                    sslVerCell.Merge = true;
                    sslVerCell.Value = "System OpenSSL";
                    sslVerCell.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
                    sslVerCell.Style.WrapText = true;
                }


                sheet.PrinterSettings.Orientation = eOrientation.Portrait;
                sheet.PrinterSettings.PaperSize = ePaperSize.A3;

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
