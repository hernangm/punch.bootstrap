using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web;

namespace Punch.Bootstrap
{
    public abstract class AddOn : IHtmlString
    {
        public enum Positions
        {
            prepend,
            append
        }

        public Positions Position { get; set; }

        protected AddOn(Positions position)
        {
            this.Position = position;
        }

        public abstract string ToHtmlString();
    }
}
