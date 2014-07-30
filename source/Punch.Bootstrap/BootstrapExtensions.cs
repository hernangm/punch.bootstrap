using Punch.Bootstrap;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Punch.Helpers
{
    public static class BootstrapExtensions
    {
        public static TType PrependAddOn<TType>(this IField<TType> field, string content) where TType : IField
        {
            return field.AddAddOn(new TextAddOn(content, AddOn.Positions.prepend));
        }

        public static TType AppendAddOn<TType>(this IField<TType> field, string content) where TType : IField
        {
            return field.AddAddOn(new TextAddOn(content, AddOn.Positions.append));
        }

        private static TType AddAddOn<TType>(this IField<TType> field, AddOn addOn) where TType : IField
        {
            AddOnPostProcessor processor = null;
            if (field.ContainsProcessor<AddOnPostProcessor>())
            {
                processor = field.GetProcessor<AddOnPostProcessor>();
            }
            else
            {
                processor = new AddOnPostProcessor();
                field.RegisterProcessor(processor);
            }
            processor.Add(addOn);
            return (TType)field;
        }
    }
}
