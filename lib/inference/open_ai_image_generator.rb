# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class OpenAiImageGenerator
      TIMEOUT = 60

      def self.create_uploads!(
        prompts,
        model:,
        size: nil,
        api_key: nil,
        api_url: nil,
        user_id:,
        for_private_message: false,
        n: 1,
        quality: nil,
        style: nil,
        background: nil,
        moderation: "low",
        output_compression: nil,
        output_format: nil,
        title: nil
      )
        # Get the API responses in parallel threads
        api_responses =
          generate_images_in_threads(
            prompts,
            model: model,
            size: size,
            api_key: api_key,
            api_url: api_url,
            n: n,
            quality: quality,
            style: style,
            background: background,
            moderation: moderation,
            output_compression: output_compression,
            output_format: output_format,
          )

        create_uploads_from_responses(api_responses, user_id, for_private_message, title)
      end

      # Method for image editing that returns Upload objects
      def self.create_edited_upload!(
        images,
        prompt,
        mask: nil,
        model: "gpt-image-1",
        size: "auto",
        api_key: nil,
        api_url: nil,
        user_id:,
        for_private_message: false,
        n: 1,
        quality: nil
      )
        api_response =
          edit_images(
            images,
            prompt,
            mask: mask,
            model: model,
            size: size,
            api_key: api_key,
            api_url: api_url,
            n: n,
            quality: quality,
          )

        create_uploads_from_responses([api_response], user_id, for_private_message).first
      end

      # Common method to create uploads from API responses
      def self.create_uploads_from_responses(
        api_responses,
        user_id,
        for_private_message,
        title = nil
      )
        all_uploads = []

        api_responses.each do |response|
          next unless response

          response[:data].each_with_index do |image, index|
            Tempfile.create("ai_image_#{index}.png") do |file|
              file.binmode
              file.write(Base64.decode64(image[:b64_json]))
              file.rewind

              upload =
                UploadCreator.new(
                  file,
                  title || "image.png",
                  for_private_message: for_private_message,
                ).create_for(user_id)

              all_uploads << {
                # Use revised_prompt if available (DALL-E 3), otherwise use original prompt
                prompt: image[:revised_prompt] || response[:original_prompt],
                upload: upload,
              }
            end
          end
        end

        all_uploads
      end

      def self.generate_images_in_threads(
        prompts,
        model:,
        size:,
        api_key:,
        api_url:,
        n:,
        quality:,
        style:,
        background:,
        moderation:,
        output_compression:,
        output_format:
      )
        prompts = [prompts] unless prompts.is_a?(Array)
        prompts = prompts.take(4) # Limit to 4 prompts max

        # Use provided values or defaults
        api_key ||= SiteSetting.ai_openai_api_key
        api_url ||= SiteSetting.ai_openai_image_generation_url

        # Thread processing
        threads = []
        prompts.each do |prompt|
          threads << Thread.new(prompt) do |inner_prompt|
            attempts = 0
            begin
              perform_generation_api_call!(
                inner_prompt,
                model: model,
                size: size,
                api_key: api_key,
                api_url: api_url,
                n: n,
                quality: quality,
                style: style,
                background: background,
                moderation: moderation,
                output_compression: output_compression,
                output_format: output_format,
              )
            rescue => e
              attempts += 1
              sleep 2
              retry if attempts < 3
              Discourse.warn_exception(e, message: "Failed to generate image for prompt #{prompt}")
              puts "Error generating image for prompt: #{prompt} #{e}" if Rails.env.development?
              nil
            end
          end
        end

        threads_complete = false
        threads_complete = threads.all? { |t| t.join(2) } until threads_complete

        threads.filter_map(&:value)
      end

      def self.edit_images(
        images,
        prompt,
        mask: nil,
        model: "gpt-image-1",
        size: "auto",
        api_key: nil,
        api_url: nil,
        n: 1,
        quality: nil
      )
        images = [images] if !images.is_a?(Array)

        # For dall-e-2, only one image is supported
        if model == "dall-e-2" && images.length > 1
          raise "DALL-E 2 only supports editing one image at a time"
        end

        # For gpt-image-1, limit to 16 images
        images = images.take(16) if model == "gpt-image-1" && images.length > 16

        # Use provided values or defaults
        api_key ||= SiteSetting.ai_openai_api_key
        api_url ||= SiteSetting.ai_openai_image_edit_url

        # Execute edit API call
        attempts = 0
        begin
          perform_edit_api_call!(
            images,
            prompt,
            mask: mask,
            model: model,
            size: size,
            api_key: api_key,
            api_url: api_url,
            n: n,
            quality: quality,
          )
        rescue => e
          attempts += 1
          sleep 2
          retry if attempts < 3
          if Rails.env.development? || Rails.env.test?
            puts "Error editing image(s) with prompt: #{prompt} #{e}"
            p e
          end
          Discourse.warn_exception(e, message: "Failed to edit image(s) with prompt #{prompt}")
          nil
        end
      end

      # Image generation API call method
      def self.perform_generation_api_call!(
        prompt,
        model:,
        size: nil,
        api_key: nil,
        api_url: nil,
        n: 1,
        quality: nil,
        style: nil,
        background: nil,
        moderation: nil,
        output_compression: nil,
        output_format: nil
      )
        api_key ||= SiteSetting.ai_openai_api_key
        api_url ||= SiteSetting.ai_openai_image_generation_url

        uri = URI(api_url)
        headers = { "Content-Type" => "application/json" }

        if uri.host.include?("azure")
          headers["api-key"] = api_key
        else
          headers["Authorization"] = "Bearer #{api_key}"
        end

        # Build payload based on model type
        payload = { model: model, prompt: prompt, n: n }

        # Add model-specific parameters
        if model == "gpt-image-1"
          if size
            payload[:size] = size
          else
            payload[:size] = "auto"
          end
          payload[:background] = background if background
          payload[:moderation] = moderation if moderation
          payload[:output_compression] = output_compression if output_compression
          payload[:output_format] = output_format if output_format
          payload[:quality] = quality if quality
        elsif model.start_with?("dall")
          payload[:size] = size || "1024x1024"
          payload[:quality] = quality || "hd"
          payload[:style] = style if style
          payload[:response_format] = "b64_json"
        end

        # Store original prompt for upload metadata
        original_prompt = prompt

        FinalDestination::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          read_timeout: TIMEOUT,
          open_timeout: TIMEOUT,
          write_timeout: TIMEOUT,
        ) do |http|
          request = Net::HTTP::Post.new(uri, headers)
          request.body = payload.to_json

          json = nil
          http.request(request) do |response|
            if response.code.to_i != 200
              raise "OpenAI API returned #{response.code} #{response.body}"
            else
              json = JSON.parse(response.body, symbolize_names: true)
              # Add original prompt to response to preserve it
              json[:original_prompt] = original_prompt
            end
          end
          json
        end
      end

      def self.perform_edit_api_call!(
        images,
        prompt,
        mask: nil,
        model: "gpt-image-1",
        size: "auto",
        api_key:,
        api_url:,
        n: 1,
        quality: nil
      )
        uri = URI(api_url)

        # Setup for multipart/form-data request
        boundary = SecureRandom.hex
        headers = { "Content-Type" => "multipart/form-data; boundary=#{boundary}" }

        if uri.host.include?("azure")
          headers["api-key"] = api_key
        else
          headers["Authorization"] = "Bearer #{api_key}"
        end

        # Create multipart form data
        body = []

        # Add model
        body << "--#{boundary}\r\n"
        body << "Content-Disposition: form-data; name=\"model\"\r\n\r\n"

        body << "#{model}\r\n"

        # Add images
        images.each do |image|
          image_data = nil
          image_filename = nil

          # Handle different image input types
          if image.is_a?(Upload)
            image_path =
              if image.local?
                Discourse.store.path_for(image)
              else
                Discourse.store.download_safe(image, max_file_size_kb: MAX_IMAGE_SIZE)&.path
              end
            image_data = File.read(image_path)
            image_filename = File.basename(image.url)
          elsif image.is_a?(File) || image.is_a?(Tempfile)
            image_data = File.read(image.path)
            image_filename = File.basename(image.path)
          elsif image.is_a?(String) && File.exist?(image)
            image_data = File.read(image)
            image_filename = File.basename(image)
          elsif image.is_a?(String) && image.start_with?("http")
            # Download image from URL
            image_temp =
              FileHelper.download(
                image,
                max_file_size: 25.megabytes,
                tmp_file_name: "edit_image_download",
                follow_redirect: true,
              )
            image_data = File.read(image_temp)
            image_filename = File.basename(image)
          else
            raise "Unsupported image format. Must be Upload, File, path string, or URL."
          end

          body << "--#{boundary}\r\n"
          body << "Content-Disposition: form-data; name=\"image[]\"; filename=\"#{image_filename}\"\r\n"
          body << "Content-Type: image/png\r\n\r\n"
          body << image_data
          body << "\r\n"
        end

        # Add mask if provided
        if mask
          mask_data = nil
          mask_filename = nil

          # Handle different mask input types (similar to images)
          if mask.is_a?(Upload)
            mask_data = File.read(Discourse.store.path_for(mask))
            mask_filename = File.basename(mask.url)
          elsif mask.is_a?(File) || mask.is_a?(Tempfile)
            mask_data = File.read(mask.path)
            mask_filename = File.basename(mask.path)
          elsif mask.is_a?(String) && File.exist?(mask)
            mask_data = File.read(mask)
            mask_filename = File.basename(mask)
          elsif mask.is_a?(String) && mask.start_with?("http")
            # Download mask from URL
            mask_temp =
              FileHelper.download(
                mask,
                max_file_size: 4.megabytes,
                tmp_file_name: "edit_mask_download",
                follow_redirect: true,
              )
            mask_data = File.read(mask_temp)
            mask_filename = File.basename(mask)
          else
            raise "Unsupported mask format. Must be Upload, File, path string, or URL."
          end

          body << "--#{boundary}\r\n"
          body << "Content-Disposition: form-data; name=\"mask\"; filename=\"#{mask_filename}\"\r\n"
          body << "Content-Type: image/png\r\n\r\n"
          body << mask_data
          body << "\r\n"
        end

        # Add prompt
        body << "--#{boundary}\r\n"
        body << "Content-Disposition: form-data; name=\"prompt\"\r\n\r\n"
        body << "#{prompt}\r\n"

        # Add size if provided
        if size
          body << "--#{boundary}\r\n"
          body << "Content-Disposition: form-data; name=\"size\"\r\n\r\n"
          body << "#{size}\r\n"
        end

        # Add n if provided and not the default
        if n != 1
          body << "--#{boundary}\r\n"
          body << "Content-Disposition: form-data; name=\"n\"\r\n\r\n"
          body << "#{n}\r\n"
        end

        # Add quality if provided
        if quality
          body << "--#{boundary}\r\n"
          body << "Content-Disposition: form-data; name=\"quality\"\r\n\r\n"
          body << "#{quality}\r\n"
        end

        # Add response_format if provided
        if model.start_with?("dall")
          # Default to b64_json for consistency with generation
          body << "--#{boundary}\r\n"
          body << "Content-Disposition: form-data; name=\"response_format\"\r\n\r\n"
          body << "b64_json\r\n"
        end

        # End boundary
        body << "--#{boundary}--\r\n"

        # Store original prompt for upload metadata
        original_prompt = prompt

        FinalDestination::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          read_timeout: TIMEOUT,
          open_timeout: TIMEOUT,
          write_timeout: TIMEOUT,
        ) do |http|
          request = Net::HTTP::Post.new(uri.path, headers)
          request.body = body.join

          json = nil
          http.request(request) do |response|
            if response.code.to_i != 200
              raise "OpenAI API returned #{response.code} #{response.body}"
            else
              json = JSON.parse(response.body, symbolize_names: true)
              # Add original prompt to response to preserve it
              json[:original_prompt] = original_prompt
            end
          end
          json
        end
      end
    end
  end
end
