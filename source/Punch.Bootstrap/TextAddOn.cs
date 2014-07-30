using System.Web;

namespace Punch.Bootstrap
{
    public class TextAddOn : AddOn
    {
        public string Content { get; set; }

        public TextAddOn(string content, Positions position = Positions.append)
            : base(position)
        {
            this.Content = content;
        }

        public override string ToHtmlString()
        {
            return string.Format(@"<span class=""input-group-addon"">{0}</span>", this.Content);
        }
    }
}
