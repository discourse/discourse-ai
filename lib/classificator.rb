# frozen_string_literal: true

module ::DiscourseAi
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

          verdicts = classification_model.get_verdicts(classification)

          if classification_model.should_flag_based_on?(verdicts)
            accuracies = get_model_accuracies(verdicts.keys)
            flag!(target, classification, verdicts, accuracies)
          end
        end
    end

    protected

    attr_reader :classification_model

    def flag!(_target, _classification, _verdicts, _accuracies)
      raise NotImplemented
    end

    def get_model_accuracies(models)
      models
        .map do |name|
          accuracy =
            ModelAccuracy.find_or_create_by(
              model: name,
              classification_type: classification_model.type,
            )
          [name, accuracy.calculate_accuracy]
        end
        .to_h
    end

    def add_score(reviewable)
      reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:inappropriate],
        reason: "flagged_by_#{classification_model.type}",
        force_review: true,
      )
    end

    def store_classification(target, classification)
      attrs =
        classification.map do |model_name, classifications|
          {
            model_used: model_name,
            target_id: target.id,
            target_type: target.class.sti_name,
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
