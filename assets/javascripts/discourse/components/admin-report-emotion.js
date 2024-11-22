import { attributeBindings, classNames } from "@ember-decorators/component";
import Component from "@ember/component";
import { service } from "@ember/service";
import getURL from "discourse-common/lib/get-url";

@classNames("admin-report-counters")
@attributeBindings("model.description:title")
export default class AdminReportEmotion extends Component {
  @service siteSettings;

  get filterURL() {
    return getURL(`/filter?q=`);
  }

  get today() {
    return moment().format("YYYY-MM-DD");
  }

  get yesterday() {
    return moment().subtract(1, "day").format("YYYY-MM-DD");
  }

  get lastWeek() {
    return moment().subtract(1, "week").format("YYYY-MM-DD");
  }

  get lastMonth() {
    return moment().subtract(1, "month").format("YYYY-MM-DD");
  }

  get filterEnabled() {
    return this.siteSettings.experimental_topics_filter;
  }
}
