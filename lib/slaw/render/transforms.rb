require 'nokogiri'

module Slaw
  module Render

    # Support for transforming XML AN documents into HTML.
    class HTMLRenderer
      @@xslt = {
        :bylaw => Nokogiri::XSLT(File.open(File.dirname(__FILE__) + '/xsl/bylaw.xsl'))
      }

      def initialize
      end

      # Transform an XML document +doc+ (a Nokogiri::XML::Document object) into HTML.
      # Specify +base_url+ to manage the base for relative URLs generated by
      # the transform.
      def render_bylaw(doc, base_url='')
        params = { 'base_url' => base_url }

        @@xslt[:bylaw].transform(doc, Nokogiri::XSLT.quote_params(params)).to_s
      end
    end
  end
end
