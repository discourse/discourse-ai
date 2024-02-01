export function showComposerAIHelper(outletArgs, helper, featureType) {
  const enableHelper = _helperEnabled(helper.siteSettings);
  const enableAssistant = _canUseAssistant(
    helper.currentUser,
    _findAllowedGroups(helper.siteSettings.ai_helper_allowed_groups)
  );
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
    _canUseAssistant(
      helper.currentUser,
      _findAllowedGroups(helper.siteSettings.post_ai_helper_allowed_groups)
    )
  );
}

function _helperEnabled(siteSettings) {
  return (
    siteSettings.discourse_ai_enabled && siteSettings.composer_ai_helper_enabled
  );
}

function _findAllowedGroups(setting) {
  return setting.split("|").map((id) => parseInt(id, 10));
}

function _canUseAssistant(user, allowedGroups) {
  return user?.groups.some((g) => allowedGroups.includes(g.id));
}
