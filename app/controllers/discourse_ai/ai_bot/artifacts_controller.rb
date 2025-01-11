# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ArtifactsController < ApplicationController
      requires_plugin DiscourseAi::PLUGIN_NAME
      before_action :require_site_settings!

      skip_before_action :preload_json, :check_xhr, only: %i[show]

      def show
        artifact = AiArtifact.find(params[:id])

        post = Post.find_by(id: artifact.post_id)
        if artifact.metadata&.dig("public")
          # no guardian needed
        else
          raise Discourse::NotFound if !post&.topic&.private_message?
          raise Discourse::NotFound if !guardian.can_see?(post)
        end

        name = artifact.name

        if params[:version].present?
          artifact = artifact.versions.find_by(version_number: params[:version])
          raise Discourse::NotFound if !artifact
        end

        js = artifact.js || ""
        if !js.match?(%r{\A\s*<script.*</script>}mi)
          mod = ""
          mod = " type=\"module\"" if js.match?(/\A\s*import.*/)
          js = "<script#{mod}>\n#{js}\n</script>"
        end
        # Prepare the inner (untrusted) HTML document
        untrusted_html = <<~HTML
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="UTF-8">
              <title>#{ERB::Util.html_escape(name)}</title>
              <style>
                #{artifact.css}
              </style>
            </head>
            <body>
              #{artifact.html}
              #{js}
            </body>
          </html>
        HTML

        # Prepare the outer (trusted) HTML document
        trusted_html = <<~HTML
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="UTF-8">
              <title>#{ERB::Util.html_escape(name)}</title>
              <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0, user-scalable=yes, viewport-fit=cover, interactive-widget=resizes-content">
              <style>
                html, body, iframe {
                  margin: 0;
                  padding: 0;
                  width: 100%;
                  height: 100%;
                  border: 0;
                  overflow: hidden;
                }
                iframe {
                  overflow: auto;
                }
              </style>
            </head>
            <body>
              <iframe sandbox="allow-scripts allow-forms" height="100%" width="100%" srcdoc="#{ERB::Util.html_escape(untrusted_html)}" frameborder="0"></iframe>
            </body>
          </html>
        HTML

        response.headers.delete("X-Frame-Options")
        response.headers[
          "Content-Security-Policy"
        ] = "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' https://unpkg.com https://cdnjs.cloudflare.com https://ajax.googleapis.com https://cdn.jsdelivr.net;"
        response.headers["X-Robots-Tag"] = "noindex"

        # Render the content
        render html: trusted_html.html_safe, layout: false, content_type: "text/html"
      end

      private

      def require_site_settings!
        if !SiteSetting.discourse_ai_enabled ||
             !SiteSetting.ai_artifact_security.in?(%w[lax strict])
          raise Discourse::NotFound
        end
      end
    end
  end
end
