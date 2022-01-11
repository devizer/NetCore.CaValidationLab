using System;
using System.Drawing;
using System.IO;
using System.Linq;
using OfficeOpenXml;
using OfficeOpenXml.Style;

namespace FormatReport
{
    class ExcelReportBuilder
    {
        static Color HeaderColor = Color.Black;
        static Color DataColor = Color.FromArgb(255, 170, 170, 170);
        private static readonly string SheetName = "TLS Report";

        public ReportPoint[] RawReport { get; }

        public ExcelReportBuilder(ReportPoint[] rawReport)
        {
            RawReport = rawReport ?? throw new ArgumentNullException(nameof(rawReport));
        }

        public void Build(string excelFileName)
        {
            var osList = RawReport.Select(x => x.OsAndVersion).Distinct().OrderBy(x => x).ToList();
            osList = OsSorting.Sort(osList);
            Console.WriteLine($"OS: {string.Join(",", osList)}");

            var netList = RawReport.Select(x => x.GetNet()).Distinct().OrderBy(x => x).ToList();
            Console.WriteLine($".NET: {string.Join(",", netList)}");

            var siteList = RawReport.Select(x => x.Site).Distinct().OrderBy(x => x).ToList();
            Console.WriteLine($"Site: {string.Join(",", siteList)}");

            var tlsList = RawReport.Where(x => x.GetTls() != null).Select(x => x.GetTls()).Distinct().OrderBy(x => x).ToList();
            Console.WriteLine($"TLS: {string.Join(",", tlsList)}");


            var file = new FileInfo(excelFileName);
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

                                // OpenSSL Version
                                var systemOpenSslVersion = GetOpenSslVersionByOs(os);
                                var cellOpenSslVer = sheet.Cells[y + 3, 2];
                                cellOpenSslVer.Value = systemOpenSslVersion;
                                cellOpenSslVer.Style.Border.Right.SetStyleAndColor(ExcelBorderStyle.Thin, DataColor);

                                // OS
                                var cellOs = sheet.Cells[y + 3, 1];
                                cellOs.Value = os;
                                cellOs.Style.Border.Right.SetStyleAndColor(ExcelBorderStyle.Thin, DataColor);
                                cellOs.Style.Border.Left.SetStyleAndColor(ExcelBorderStyle.Thin, DataColor);
                                cellOs.Style.Indent = 1;
                                cellOs.Style.Font.Bold = true;

                                // Entire row
                                var row = sheet.Rows[y + 3];
                                row.Height = 24;
                                row.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
                                row.Style.Border.Bottom.SetStyleAndColor(ExcelBorderStyle.Thin, DataColor);
                            }

                            var point = RawReport.FirstOrDefault(
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
                sheet.PrinterSettings.LeftMargin = sheet.PrinterSettings.RightMargin = 0.5m;

                ExcelRangeColumn dataColumns = sheet.Columns[3, 2 + netList.Count * tlsList.Count];
                dataColumns.Width = 5.9;

                sheet.View.FreezePanes(3, 2);

                package.Save();
            }
        }

        string GetOpenSslVersionByOs(string os)
        {
            return RawReport
                .FirstOrDefault(x => x.OsAndVersion == os && !string.IsNullOrEmpty(x.SystemOpenSslVersion))
                ?.SystemOpenSslVersion;
        }
    }
}
