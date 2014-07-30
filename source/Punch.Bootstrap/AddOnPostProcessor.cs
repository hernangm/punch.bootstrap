using Punch.Helpers;
using System.Collections.Generic;
using System.Web.Mvc;

namespace Punch.Bootstrap
{
    public class AddOnPostProcessor : ITagProcessor
    {
        private List<AddOn> AddOns { get; set; }

        public AddOnPostProcessor()
        {
            this.AddOns = new List<AddOn>();
        }

        public void Add(AddOn addon)
        {
            this.AddOns.Add(addon);
        }

        public void PreProcess(object field)
        {
            if (this.AddOns.Count > 0)
            {
                (field as IInput).AddClass1("form-control");
            }
        }

        public string PostProcess(object field, string output)
        {
            if (this.AddOns.Count == 0)
            {
                return output;
            }
            var div = new TagBuilder("div");
            div.AddCssClass("input-group");
            div.InnerHtml = output;

            foreach (var addon in this.AddOns)
            {
                var pos = addon.Position == Bootstrap.AddOn.Positions.prepend ? 0 : div.InnerHtml.Length;
                div.InnerHtml = div.InnerHtml.Insert(pos, addon.ToHtmlString());
            }
            return div.ToString();
        }

        public bool CanProcess(object field)
        {
            return (field as IInput) != null;
        }


    }
}
