export function showComposerAIHelper(outletArgs, helper, featureType) {
  const enableHelper = _helperEnabled(helper.siteSettings);
  const enableAssistant = helper.currentUser.can_use_assistant;
  const canShowInPM = helper.siteSettings.ai_helper_allowed_in_pm;
  const enableFeature =
    helper.siteSettings.ai_helper_enabled_features.includes(featureType);

  if (outletArgs?.composer?.privateMessage) {
    return enableHelper && enableAssistant && canShowInPM && enableFeature;
  }

  return enableHelper && enableAssistant && enableFeature;
}

export function showPostAIHelper(outletArgs, helper) {
  return (
    _helperEnabled(helper.siteSettings) &&
    helper.currentUser.can_use_assistant_in_post
  );
}

function _helperEnabled(siteSettings) {
  return (
    siteSettings.discourse_ai_enabled && siteSettings.composer_ai_helper_enabled
  );
}
