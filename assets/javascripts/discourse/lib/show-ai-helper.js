export default function showAIHelper(outletArgs, helper) {
  const helperEnabled =
    helper.siteSettings.discourse_ai_enabled &&
    helper.siteSettings.composer_ai_helper_enabled;

  const allowedGroups = helper.siteSettings.ai_helper_allowed_groups
    .split("|")
    .map((id) => parseInt(id, 10));
  const canUseAssistant = helper.currentUser?.groups.some((g) =>
    allowedGroups.includes(g.id)
  );

  const canShowInPM = helper.siteSettings.ai_helper_allowed_in_pm;

  if (outletArgs?.composer?.privateMessage) {
    return helperEnabled && canUseAssistant && canShowInPM;
  }

  return helperEnabled && canUseAssistant;
}
