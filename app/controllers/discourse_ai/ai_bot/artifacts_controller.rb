# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ArtifactsController < ApplicationController

      requires_plugin DiscourseAi::PLUGIN_NAME

      skip_before_action :preload_json, :check_xhr, only: %i[show]

      def show
        artifact = AiArtifact.find(params[:id])

        post = Post.find_by(id: artifact.post_id)
        raise Discourse::NotFound unless post && guardian.can_see?(post)

        # Prepare the HTML document
        html = <<~HTML
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="UTF-8">
              <title>#{ERB::Util.html_escape(artifact.name)}</title>
              <style>
                #{artifact.css}
              </style>
            </head>
            <body>
              #{artifact.html}
              <script>
                #{artifact.js}
              </script>
            </body>
          </html>
        HTML

        response.headers.delete("X-Frame-Options")
        response.headers.delete("Content-Security-Policy")

        # Render the content
        render html: html.html_safe, layout: false, content_type: "text/html"
      end
    end
  end
end
