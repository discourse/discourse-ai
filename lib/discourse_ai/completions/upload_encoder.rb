# frozen_string_literal: true

module DiscourseAi
  module Completions
    class UploadEncoder
      def self.encode(upload_ids:, max_pixels:)
        uploads = []
        upload_ids.each do |upload_id|
          upload = Upload.find(upload_id)
          next if upload.blank?
          next if upload.width.to_i == 0 || upload.height.to_i == 0

          original_pixels = upload.width * upload.height

          image = upload

          if original_pixels > max_pixels
            ratio = max_pixels.to_f / original_pixels

            new_width = (ratio * upload.width).to_i
            new_height = (ratio * upload.height).to_i

            image = upload.get_optimized_image(new_width, new_height)
          end

          next if !image

          mime_type = MiniMime.lookup_by_filename(upload.original_filename).content_type

          path = Discourse.store.path_for(image)
          if path.blank?
            # download is protected with a DistributedMutex
            external_copy = Discourse.store.download_safe(image)
            path = external_copy&.path
          end

          encoded = Base64.strict_encode64(File.read(path))

          uploads << { base64: encoded, mime_type: mime_type }
        end
        uploads
      end
    end
  end
end
