require 'jekyll'
require 'nokogiri'
require 'digest'
require 'open-uri'
require 'uri'

##
# Provides the ability to generate a content security policy for inline scripts and styles.
# Will reuse an existing CSP or generate a new one and insert in HEAD.
module Jekyll

  module JekyllContentSecurityPolicyGenerator

    ##
    # Provides the ability to generate a content security policy for inline scripts and styles.
    # Will reuse an existing CSP or generate a new one and insert in HEAD.
    class ContentSecurityPolicyGenerator
      def initialize(document_html)
        @document_html = document_html
        @nokogiri = Nokogiri::HTML(document_html)

        @csp_frame_src = ['\'self\'']
        @csp_image_src = ['\'self\'']
        @csp_style_src = ['\'self\'']
        @csp_script_src = ['\'self\'']
        @csp_unknown = []
      end

      ##
      # Creates an HTML content security policy meta tag.
      def generate_convert_security_policy_meta_tag
        meta_content = ""

        @csp_script_src = @csp_script_src.uniq
        @csp_image_src = @csp_image_src.uniq
        @csp_style_src = @csp_style_src.uniq
        @csp_script_src = @csp_script_src.uniq
        @csp_unknown = @csp_unknown.uniq

        if @csp_frame_src.length > 0
          @csp_script_src.uniq
          meta_content += "frame-src " + @csp_frame_src.join(' ') + '; '
        end

        if @csp_image_src.length > 0
          meta_content += "img-src " + @csp_image_src.join(' ') + '; '
        end

        if @csp_style_src.length > 0
          meta_content += "style-src " + @csp_style_src.join(' ') + '; '
        end

        if @csp_script_src.length > 0
          meta_content += "script-src " + @csp_script_src.join(' ') + '; '
        end

        if @csp_unknown.length > 0
          @csp_unknown.each do |find|
            find_name = find[0]
            find = find.drop(1)
            meta_content += find_name + " " + find.join(' ') + '; '
          end
        end

        if @nokogiri.at("head")
          Jekyll.logger.info "Generated content security policy, inserted in HEAD."
          @nokogiri.at("head") << "<meta http-equiv=\"Content-Security-Policy\" content=\"" + meta_content + "\">"
        elsif @nokogiri.at("body")
          Jekyll.logger.info "Generated content security policy, inserted in BODY."
          @nokogiri.at("body") << "<meta http-equiv=\"Content-Security-Policy\" content=\"" + meta_content + "\">"
        else
          Jekyll.logger.error "Generated content security policy but found no-where to insert it."
        end

      end

      ##
      # Parse an existing content security policy meta tag
      def parse_existing_meta_element()
        csp = @nokogiri.at('meta[http-equiv="Content-Security-Policy"]')

        if csp
          content = csp.attr('content')
          content = content.strip! || content
          policies = content.split(';')

          policies.each do |policy|
            policy = policy.strip! || policy

            if policy.include? ' '
              policy_parts = policy.split(' ')

              if policy_parts[0] == 'script-src'
                @csp_script_src.concat(policy_parts.drop(1))
              elsif policy_parts[0] == 'style-src'
                @csp_style_src.concat(policy_parts.drop(1))
              elsif policy_parts[0] == 'img-src'
                @csp_image_src.concat(policy_parts.drop(1))
              elsif policy_parts[0] == 'frame-src'
                @csp_frame_src.concat(policy_parts.drop(1))
              else
                @csp_unknown.concat([policy_parts])
              end

            else
              Jekyll.logger.warn "Incorrect existing content security policy meta tag found, skipping."
            end
          end

          @nokogiri.search('meta[http-equiv="Content-Security-Policy"]').each do |el|
            el.remove
          end
        end
      end

      ##
      # This function converts elements with style="color:red" attributes into inline styles
      def convert_all_inline_styles_attributes
        @nokogiri.css('*').each do |find|
          find_src = find.attr('style')

          if find_src
            if find.attr('id')
              element_id = find.attr('id')
            else
              hash = Digest::MD5.hexdigest find_src + "#{Random.rand(11)}"
              element_id = "csp-gen-" + hash
              find["id"] = element_id
            end

            new_element = "<style>#" + element_id + " { " + find_src + " } </style>"
            find.remove_attribute("style")

            if @nokogiri.at('head')
              @nokogiri.at('head') << new_element
              Jekyll.logger.info'Converting style attribute to inline style, inserted into HEAD.'
            else
              if @nokogiri.at('body')
                @nokogiri.at('body') << new_element
                Jekyll.logger.info'Converting style attribute to inline style, inserted into BODY.'
              else
                Jekyll.logger.warn'Unable to convert style attribute to inline style, no HEAD or BODY found.'
              end
            end
          end
        end
      end

      ##
      # Find all images
      def find_images
        @nokogiri.css('img').each do |find|
          find_src = find.attr('src')

          if find_src and find_src.start_with?('http', 'https')
            @csp_image_src.push find_src.match(/(.*\/)+(.*$)/)[1]
          end
        end

        @nokogiri.css('style').each do |find|
          finds = find.content.scan(/url\(([^\)]+)\)/)

          finds.each do |innerFind|
            innerFind = innerFind[0]
            innerFind = innerFind.tr('\'"', '')
            if innerFind.start_with?('http', 'https')
              @csp_image_src.push self.get_domain(innerFind)
            end
          end
        end

      end

      ##
      # Find all scripts
      def find_scripts
        @nokogiri.css('script').each do |find|
          if find.attr('src')
            find_src = find.attr('src')

            if find_src and find_src.start_with?('http', 'https')
              @csp_script_src.push find_src.match(/(.*\/)+(.*$)/)[1]
            end

          else
            @csp_script_src.push self.generate_sha256_content_hash find.content
          end
        end
      end

      ##
      # Find all stylesheets
      def find_styles
        @nokogiri.css('style').each do |find|
          if find.attr('src')
            find_src = find.attr('src')

            if find_src and find_src.start_with?('http', 'https')
              @csp_style_src.push find_src.match(/(.*\/)+(.*$)/)[1]
            end

          else
            @csp_style_src.push self.generate_sha256_content_hash find.content
          end
        end
      end

      ##
      # Find all iframes
      def find_iframes
        @nokogiri.css('iframe').each do |find|
          find_src = find.attr('src')

          if find_src and find_src.start_with?('http', 'https')
            @csp_frame_src.push find_src.match(/(.*\/)+(.*$)/)[1]
          end
        end
      end

      def get_domain(url)
        uri = URI.parse(url)
        "#{uri.scheme}://#{uri.host}"
      end

      ##
      # Generate a content hash
      def generate_sha256_content_hash(content)
        hash = Digest::SHA2.base64digest content
        "'sha256-#{hash}'"
      end

      ##
      # Builds an HTML meta tag based on the found inline scripts and style hashes
      def run
        self.parse_existing_meta_element

        self.convert_all_inline_styles_attributes

        # Find elements in document
        self.find_images
        self.find_styles
        self.find_scripts
        self.find_iframes

        self.generate_convert_security_policy_meta_tag

        @nokogiri.to_html
      end
    end

    ##
    # Write the file contents back.
    def write_file_contents(dest, content)
      FileUtils.mkdir_p(File.dirname(dest))
      File.open(dest, 'w') do |f|
        f.write(content)
      end
    end

    ##
    # Write document contents
    def write(dest)
      dest_path = destination(dest)
      if File.extname(dest_path) == ".html"
        content_security_policy_generator = ContentSecurityPolicyGenerator.new output
        output = content_security_policy_generator.run
        write_file_contents(dest_path, output)
      end
    end

  end

  class Document
    include JekyllContentSecurityPolicyGenerator

    ##
    # Write document contents
    def write(dest)
      super dest
      trigger_hooks(:post_write)
    end
  end

  class Page
    include JekyllContentSecurityPolicyGenerator

    ##
    # Write page contents
    def write(dest)
      super dest
      Jekyll::Hooks.trigger hook_owner, :post_write, self
    end
  end
end
