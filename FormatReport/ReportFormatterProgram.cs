using System;
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
        static void Main(string[] args)
        {
            TlsReportReader rdr = new TlsReportReader();
            var rawReport = rdr.ReadRaw("TLS-Reports");
            foreach (var reportPoint in rawReport)
                reportPoint.OsAndVersion = FormatOsName(reportPoint.OsAndVersion);

            var osList = rawReport.Select(x => x.OsAndVersion).Distinct().OrderBy(x => x).ToList();
            osList = OsSorting.Sort(osList);
            Console.WriteLine($"OS: {string.Join(",",osList)}");

            var netList = rawReport.Select(x => x.GetNet()).Distinct().OrderBy(x => x).ToList();
            Console.WriteLine($".NET: {string.Join(",", netList)}");

            var siteList = rawReport.Select(x => x.Site).Distinct().OrderBy(x => x).ToList();
            Console.WriteLine($"Site: {string.Join(",", siteList)}");

            var tlsList = rawReport.Where(x => x.GetTls() != null).Select(x => x.GetTls()).Distinct().OrderBy(x => x).ToList();
            Console.WriteLine($"TLS: {string.Join(",", tlsList)}");


            var file = new FileInfo(@"TLS-Report.xlsx");
            Console.WriteLine(file.FullName);
            using (var package = new ExcelPackage(file))
            {
                var sheet = package.Workbook.Worksheets.FirstOrDefault(x => x.Name == "TLS Report");
                if (sheet == null)
                    sheet = package.Workbook.Worksheets.Add("TLS Report");

                int iTls = 0;
                foreach (var tls in tlsList)
                {
                    var cellTlsHeader = sheet.Cells[1, 2 + iTls * netList.Count, 1, (iTls + 1) * netList.Count+1];
                    cellTlsHeader.Value = $"TLS {tls}";
                    cellTlsHeader.Merge = true;
                    cellTlsHeader.Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;

                    int iNet = 0;
                    foreach (var net in netList)
                    {
                        var cellNetHeader = sheet.Cells[2, 2+iTls * netList.Count + iNet];
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
                                sheet.Cells[y + 3, 1].Value = os;
                                sheet.Cells[y + 3, 1].Style.Border.Right.Style = ExcelBorderStyle.Thin;
                                sheet.Cells[y + 3, 1].Style.Border.Left.Style = ExcelBorderStyle.Thin;
                                sheet.Cells[y + 3, 1].Style.Indent = 1;
                                var row = sheet.Rows[y + 3];
                                row.Height = 24;
                                row.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
                                row.Style.Border.Bottom.Style = ExcelBorderStyle.Thin;
                            }

                            var point = rawReport.FirstOrDefault(
                                x => x.GetTls() == tls && x.GetNet() == net && x.OsAndVersion == os
                            );
                            var cellPoint = sheet.Cells[y + 3, x + 2];
                            cellPoint.Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;
                            if (iNet+1 == netList.Count)
                                cellPoint.Style.Border.Right.Style = ExcelBorderStyle.Thin;

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
                sheet.Cells[1,1].EntireColumn.AutoFit(25);
                // sheet.Cells[1, 1].EntireColumn.Width = 90;

                //create a range for the table
                ExcelRange tableHeader = sheet.Cells[1, 1, 2, 1 + netList.Count * tlsList.Count];
                tableHeader.Style.Border.BorderAround(ExcelBorderStyle.Thin);
                var modelCells = tableHeader;
                var border1 = modelCells.Style.Border.Top.Style = modelCells.Style.Border.Left.Style = modelCells.Style.Border.Right.Style = modelCells.Style.Border.Bottom.Style = ExcelBorderStyle.Medium;
                tableHeader.Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;

                var rowsHeader = sheet.Rows[1, 2];
                rowsHeader.Height = 26;
                rowsHeader.Style.VerticalAlignment = ExcelVerticalAlignment.Center;

                ExcelRange topLeftCell = sheet.Cells[1, 1, 2, 1];
                topLeftCell.Merge = true;
                topLeftCell.Value = ".NET Core on Linux";
                topLeftCell.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
                sheet.PrinterSettings.Orientation = eOrientation.Portrait;
                sheet.PrinterSettings.PaperSize = ePaperSize.A3;

                var dataColumns = sheet.Columns[2, 1 + netList.Count * tlsList.Count];
                dataColumns.Width = 5.9;


                sheet.View.FreezePanes(3, 2);


                package.Save();
            }
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
