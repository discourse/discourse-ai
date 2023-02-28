# frozen_string_literal: true

module ::DiscourseAI
  class Classificator
    def initialize(classification_model)
      @classification_model = classification_model
    end

    def classify!(target)
      return :cannot_classify unless classification_model.can_classify?(target)

      classification_model
        .request(target)
        .tap do |classification|
          store_classification(target, classification)

          if classification_model.should_flag_based_on?(classification)
            flag!(target, classification)
          end
        end
    end

    protected

    attr_reader :classification_model

    def flag!(_target, _classification)
      raise NotImplemented
    end

    def store_classification(target, classification)
      attrs =
        classification.map do |model_name, classifications|
          {
            model_used: model_name,
            target_id: target.id,
            target_type: target.class.name,
            classification_type: classification_model.type,
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

    def flagger
      Discourse.system_user
    end
  end
end
