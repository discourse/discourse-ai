# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class PostClassification
      def bulk_classify!(relation)
        http_pool_size = 100
        pool =
          Concurrent::CachedThreadPool.new(
            min_threads: 0,
            max_threads: http_pool_size,
            idletime: 30,
          )

        available_classifiers = classifiers
        base_url = Discourse.base_url

        promised_classifications =
          relation
            .map do |record|
              text = prepare_text(record)
              next if text.blank?

              Concurrent::Promises
                .fulfilled_future({ target: record, text: text }, pool)
                .then_on(pool) do |w_text|
                  results = Concurrent::Hash.new

                  promised_target_results =
                    available_classifiers.map do |c|
                      Concurrent::Promises.future_on(pool) do
                        results[c.model_name] = request_with(w_text[:text], c, base_url)
                      end
                    end

                  Concurrent::Promises
                    .zip(*promised_target_results)
                    .then_on(pool) { |_| w_text.merge(classification: results) }
                end
                .flat(1)
            end
            .compact

        Concurrent::Promises
          .zip(*promised_classifications)
          .value!
          .each { |r| store_classification(r[:target], r[:classification]) }

        pool.shutdown
        pool.wait_for_termination
      end

      def classify!(target)
        return if target.blank?

        to_classify = prepare_text(target)
        return if to_classify.blank?

        results =
          classifiers.reduce({}) do |memo, model|
            memo[model.model_name] = request_with(to_classify, model)
            memo
          end

        store_classification(target, results)
      end

      private

      def prepare_text(target)
        content =
          if target.post_number == 1
            "#{target.topic.title}\n#{target.raw}"
          else
            target.raw
          end

        Tokenizer::BertTokenizer.truncate(content, 512)
      end

      def classifiers
        DiscourseAi::Sentiment::SentimentSiteSettingJsonSchema.values
      end

      def request_with(content, config, base_url = Discourse.base_url)
        result =
          DiscourseAi::Inference::HuggingFaceTextEmbeddings.classify(content, config, base_url)
        transform_result(result)
      end

      def transform_result(result)
        hash_result = {}
        result.each { |r| hash_result[r[:label]] = r[:score] }
        hash_result
      end

      def store_classification(target, classification)
        attrs =
          classification.map do |model_name, classifications|
            {
              model_used: model_name,
              target_id: target.id,
              target_type: target.class.sti_name,
              classification_type: :sentiment,
              classification: classifications,
              updated_at: DateTime.now,
              created_at: DateTime.now,
            }
          end

        ClassificationResult.upsert_all(
          attrs,
          unique_by: %i[target_id target_type model_used],
          update_only: %i[classification],
        )
      end
    end
  end
end
