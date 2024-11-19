import Component from "@ember/component";
import { attributeBindings, classNames } from "@ember-decorators/component";
import getURL from "discourse-common/lib/get-url";

@classNames("admin-report-counters")
@attributeBindings("model.description:title")
export default class AdminReportEmotion extends Component {
  get filterURL() {
    let aMonthAgo = moment().subtract(1, "month").format("YYYY-MM-DD");
    return getURL(`/filter?q=activity-after%3A${aMonthAgo}%20order%3A`);
  }
}
