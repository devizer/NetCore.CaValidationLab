using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace FormatReport
{
    class OsSorting
    {
        static string[] Kinds = { "Debian 8", "Debian 9", "Debian 10", "Debian 11", "Ubuntu", "Open SUSE 42", "Open SUSE 15", "Open SUSE", "CentOS", "Fedora" };

        public static List<string> Sort(List<string> osList)
        {
            int GetKind(string os)
            {
                var found = Kinds.Select((kind,index) => new {kind, index}).FirstOrDefault(x => os.StartsWith(x.kind));
                if (found != null) return found.index;
                return int.MaxValue;
            }

            return osList
                .OrderBy(x => GetKind(x))
                .ThenBy(x => x)
                .ToList();
        }
    }
}
